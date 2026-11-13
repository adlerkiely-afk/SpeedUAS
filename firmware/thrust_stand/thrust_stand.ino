/*
  SpeedUAS thrust stand logger
  Arduino Nano + SparkFun HX711 (SEN-13879) + 5 kg bar load cell (SEN-14729)

  Streams one CSV line per HX711 conversion over USB serial:
      t_s,raw,grams,mark
  Lines that start with '#' are messages, not data.

  No libraries to install. EEPROM.h ships with the Arduino AVR core.

  Wiring (see firmware/README.md):
      HX711 DAT -> D3      HX711 CLK -> D2
      HX711 VCC and VDD -> 5V      HX711 GND -> GND
  For 80 samples/s the RATE jumper on the HX711 board must be cut.
  Send 'r' to check the rate the board is actually producing.

  Commands (one per line, 115200 baud, newline terminated):
      t          tare (rig at rest, about 1 s)
      c <grams>  add a calibration point at a known mass, e.g.  c 500
      p          print calibration points and the fit
      s          apply the fit and save it to EEPROM
      x          clear calibration points
      g / h      start / stop the data stream
      m          increment the mark column (event marker)
      r          measure the sample rate
      ?          help
*/

#include <EEPROM.h>

const uint8_t PIN_DOUT = 3;
const uint8_t PIN_SCK  = 2;
const unsigned long BAUD = 115200;

const uint8_t  AVG_N      = 80;      // samples averaged for tare and for each calibration point
const uint8_t  MAX_POINTS = 16;      // enough for 8 masses up and back down
const uint16_t READY_TIMEOUT_MS = 500;

const uint32_t EEPROM_MAGIC = 0x53554131UL;   // "SUA1"
struct Saved {
  uint32_t magic;
  float gramsPerCount;
};

// ---- state ----------------------------------------------------------------------------------
float gramsPerCount = 0.0f;   // 0 = not calibrated, grams column prints nan
bool  calibrated    = false;
long  tareRaw       = 0;
bool  streaming     = true;
uint16_t mark       = 0;

long  calRaw[MAX_POINTS];
float calGrams[MAX_POINTS];
uint8_t calCount = 0;

// elapsed time since boot, kept as seconds + microseconds so it never wraps in a session
uint32_t tSec = 0, tMicros = 0, lastMicros = 0;

char    lineBuf[24];
uint8_t lineLen = 0;

// ---- HX711 ----------------------------------------------------------------------------------
bool hxReady() {
  return digitalRead(PIN_DOUT) == LOW;
}

bool hxWait(uint16_t timeoutMs) {
  unsigned long t0 = millis();
  while (!hxReady()) {
    if (millis() - t0 > timeoutMs) return false;
  }
  return true;
}

// Reads one 24-bit conversion, channel A, gain 128. Call only when hxReady().
// Interrupts are off only while SCK is high: the HX711 powers down if SCK stays high
// for more than 60 us, and keeping the window short avoids dropping serial bytes.
long hxRead() {
  uint32_t v = 0;
  for (uint8_t i = 0; i < 24; i++) {
    noInterrupts();
    digitalWrite(PIN_SCK, HIGH);
    delayMicroseconds(1);
    uint8_t b = digitalRead(PIN_DOUT);
    digitalWrite(PIN_SCK, LOW);
    interrupts();
    v = (v << 1) | (b ? 1UL : 0UL);
  }
  noInterrupts();                       // 25th pulse: next conversion is channel A, gain 128
  digitalWrite(PIN_SCK, HIGH);
  delayMicroseconds(1);
  digitalWrite(PIN_SCK, LOW);
  interrupts();
  if (v & 0x800000UL) v |= 0xFF000000UL;   // sign-extend 24 -> 32 bit
  return (long)v;
}

// Average n conversions. Returns false if the HX711 stops answering.
bool hxAverage(uint8_t n, long &out) {
  long sum = 0;                         // 255 x 2^23 fits in 32 bits
  for (uint8_t i = 0; i < n; i++) {
    if (!hxWait(READY_TIMEOUT_MS)) return false;
    sum += hxRead();
  }
  out = sum / n;
  return true;
}

// ---- time -----------------------------------------------------------------------------------
void updateClock() {
  uint32_t now = micros();
  tMicros += now - lastMicros;          // unsigned subtraction handles the 71 min wrap
  lastMicros = now;
  while (tMicros >= 1000000UL) {
    tMicros -= 1000000UL;
    tSec++;
  }
}

void printClock() {
  Serial.print(tSec);
  Serial.print('.');
  uint32_t frac = tMicros / 100;        // 0.1 ms resolution, 4 digits
  if (frac < 1000) Serial.print('0');
  if (frac < 100)  Serial.print('0');
  if (frac < 10)   Serial.print('0');
  Serial.print(frac);
}

// ---- calibration ----------------------------------------------------------------------------
// Least-squares line through the points: grams = slope * raw + intercept.
// Only the slope is kept; the zero comes from tare. Returns false with fewer than two
// different masses.
bool fitLine(float &slope, float &intercept) {
  if (calCount < 2) return false;
  float xm = 0, ym = 0;
  for (uint8_t i = 0; i < calCount; i++) {
    xm += (float)(calRaw[i] - calRaw[0]);   // work relative to point 0 to keep float precision
    ym += calGrams[i];
  }
  xm /= calCount;
  ym /= calCount;
  float sxx = 0, sxy = 0;
  for (uint8_t i = 0; i < calCount; i++) {
    float dx = (float)(calRaw[i] - calRaw[0]) - xm;
    sxx += dx * dx;
    sxy += dx * (calGrams[i] - ym);
  }
  if (sxx < 1.0f) return false;
  slope = sxy / sxx;
  intercept = ym - slope * xm;              // intercept in the shifted frame (raw - calRaw[0])
  return true;
}

void printCal() {
  Serial.print(F("# cal points: "));
  Serial.println(calCount);
  float slope, icpt;
  bool ok = fitLine(slope, icpt);
  float span = 0, worst = 0;
  for (uint8_t i = 0; i < calCount; i++) {
    Serial.print(F("#   "));
    Serial.print(i + 1);
    Serial.print(F("  raw "));
    Serial.print(calRaw[i]);
    Serial.print(F("  mass_g "));
    Serial.print(calGrams[i], 2);
    if (ok) {
      float res = calGrams[i] - (slope * (float)(calRaw[i] - calRaw[0]) + icpt);
      Serial.print(F("  residual_g "));
      Serial.print(res, 2);
      if (fabs(res) > worst) worst = fabs(res);
      if (fabs(calGrams[i]) > span) span = fabs(calGrams[i]);
    }
    Serial.println();
  }
  if (ok) {
    Serial.print(F("# fit: g_per_count "));
    Serial.print(slope, 7);
    Serial.print(F("  worst_residual_g "));
    Serial.print(worst, 2);
    if (span > 0) {
      Serial.print(F("  ("));
      Serial.print(100.0f * worst / span, 3);
      Serial.print(F(" % of largest mass)"));
    }
    Serial.println();
    Serial.println(F("# send s to apply and save"));
  } else {
    Serial.println(F("# fit: need at least two different masses"));
  }
  Serial.print(F("# in use: g_per_count "));
  if (calibrated) Serial.println(gramsPerCount, 7);
  else Serial.println(F("none (not calibrated)"));
}

void doTare() {
  Serial.println(F("# taring, keep the rig still"));
  long r;
  if (!hxAverage(AVG_N, r)) {
    Serial.println(F("# ERR no data from HX711 (check wiring)"));
    return;
  }
  tareRaw = r;
  Serial.print(F("# tare raw "));
  Serial.println(tareRaw);
}

void addPoint(float grams) {
  if (calCount >= MAX_POINTS) {
    Serial.println(F("# ERR point table full, send x to clear"));
    return;
  }
  long r;
  if (!hxAverage(AVG_N, r)) {
    Serial.println(F("# ERR no data from HX711 (check wiring)"));
    return;
  }
  calRaw[calCount] = r;
  calGrams[calCount] = grams;
  calCount++;
  Serial.print(F("# point "));
  Serial.print(calCount);
  Serial.print(F(": raw "));
  Serial.print(r);
  Serial.print(F("  mass_g "));
  Serial.println(grams, 2);
}

void saveCal() {
  float slope, icpt;
  if (!fitLine(slope, icpt)) {
    Serial.println(F("# ERR no fit to save"));
    return;
  }
  gramsPerCount = slope;
  calibrated = true;
  Saved s = { EEPROM_MAGIC, gramsPerCount };
  EEPROM.put(0, s);
  Serial.print(F("# saved g_per_count "));
  Serial.println(gramsPerCount, 7);
}

void measureRate() {
  const uint8_t n = 160;
  long dummy;
  if (!hxAverage(1, dummy)) {               // line up on a conversion edge
    Serial.println(F("# ERR no data from HX711 (check wiring)"));
    return;
  }
  uint32_t t0 = micros();
  for (uint8_t i = 0; i < n; i++) {
    if (!hxWait(READY_TIMEOUT_MS)) {
      Serial.println(F("# ERR HX711 stopped answering"));
      return;
    }
    hxRead();
  }
  float hz = 1.0e6f * n / (float)(micros() - t0);
  Serial.print(F("# sample rate "));
  Serial.print(hz, 1);
  Serial.println(F(" Hz (about 80 with the RATE jumper cut, about 10 if not)"));
}

void printHelp() {
  Serial.println(F("# t tare | c <grams> add cal point | p print cal | s save cal | x clear points"));
  Serial.println(F("# g start stream | h stop stream | m mark | r sample rate | ? help"));
}

void printHeader() {
  Serial.println(F("t_s,raw,grams,mark"));
}

// ---- command handling -----------------------------------------------------------------------
void handleLine() {
  if (lineLen == 0) return;
  lineBuf[lineLen] = '\0';
  char cmd = lineBuf[0];
  switch (cmd) {
    case 't': doTare(); break;
    case 'c': {
      const char *arg = lineBuf + 1;
      while (*arg == ' ') arg++;
      if (*arg == '\0') {
        Serial.println(F("# ERR give the mass in grams, e.g. c 500"));
      } else {
        addPoint(atof(arg));
      }
      break;
    }
    case 'p': printCal(); break;
    case 's': saveCal(); break;
    case 'x': calCount = 0; Serial.println(F("# cal points cleared")); break;
    case 'g': streaming = true; printHeader(); break;
    case 'h': streaming = false; Serial.println(F("# stream stopped")); break;
    case 'm':
      mark++;
      Serial.print(F("# mark "));
      Serial.println(mark);
      break;
    case 'r': measureRate(); break;
    case '?': printHelp(); break;
    default:
      Serial.print(F("# ERR unknown command: "));
      Serial.println(lineBuf);
  }
  lineLen = 0;
}

void pollSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n' || ch == '\r') {
      handleLine();
    } else if (lineLen < sizeof(lineBuf) - 1) {
      lineBuf[lineLen++] = ch;
    }
  }
}

// ---- setup / loop ---------------------------------------------------------------------------
void setup() {
  pinMode(PIN_DOUT, INPUT);
  pinMode(PIN_SCK, OUTPUT);
  digitalWrite(PIN_SCK, LOW);
  Serial.begin(BAUD);

  Saved s;
  EEPROM.get(0, s);
  if (s.magic == EEPROM_MAGIC && s.gramsPerCount == s.gramsPerCount && s.gramsPerCount != 0.0f) {
    gramsPerCount = s.gramsPerCount;
    calibrated = true;
  }

  Serial.println(F("# SpeedUAS thrust stand logger"));
  Serial.print(F("# g_per_count "));
  if (calibrated) Serial.println(gramsPerCount, 7);
  else Serial.println(F("none (not calibrated, grams column is nan)"));
  printHelp();

  delay(500);                 // let the HX711 settle after power-up
  doTare();                   // the Nano resets when the serial port opens, so this runs each session
  lastMicros = micros();
  printHeader();
}

void loop() {
  pollSerial();
  if (!hxReady()) return;

  updateClock();              // timestamp at the moment the conversion became available
  long raw = hxRead();
  if (!streaming) return;

  printClock();
  Serial.print(',');
  Serial.print(raw);
  Serial.print(',');
  if (calibrated) Serial.print(gramsPerCount * (float)(raw - tareRaw), 2);
  else Serial.print(F("nan"));
  Serial.print(',');
  Serial.println(mark);
}
