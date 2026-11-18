// SpeedUAS thrust stand logger: Arduino Nano + SparkFun HX711 + 5 kg bar load cell.
// Streams "t_s,raw,grams,mark" over USB, one line per HX711 conversion. Lines starting '#' are messages.
// Wiring and commands: firmware/README.md, or send '?'.

#include <EEPROM.h>

const uint8_t PIN_DOUT = 3;                  // HX711 DAT
const uint8_t PIN_SCK  = 2;                  // HX711 CLK
const unsigned long BAUD = 115200;
const uint8_t  AVG_N = 80;                   // samples per tare or calibration point (1 s at 80 Hz)
const uint8_t  MAX_POINTS = 16;
const uint16_t READY_TIMEOUT_MS = 500;
const uint32_t EEPROM_MAGIC = 0x53554131UL;  // "SUA1"

struct Saved { uint32_t magic; float gramsPerCount; };

float gramsPerCount = 0;                     // calibration slope, grams per HX711 count; 0 = not calibrated
long  tareRaw = 0;
bool  streaming = true;
uint16_t mark = 0;

long  calRaw[MAX_POINTS];
float calGrams[MAX_POINTS];
uint8_t calCount = 0;

uint32_t tSec = 0, tMicros = 0, lastMicros = 0;   // time since boot as s + us, so it never wraps

char lineBuf[24];
uint8_t lineLen = 0;

bool hxWait(uint16_t timeoutMs) {
  unsigned long t0 = millis();
  while (digitalRead(PIN_DOUT) == HIGH) {
    if (millis() - t0 > timeoutMs) return false;
  }
  return true;
}

// One 24-bit conversion, channel A, gain 128. Interrupts are off only while SCK is high:
// the HX711 powers down if SCK stays high for more than 60 us.
long hxRead() {
  uint32_t v = 0;
  for (uint8_t i = 0; i < 25; i++) {         // 25th pulse selects channel A, gain 128 for the next read
    noInterrupts();
    digitalWrite(PIN_SCK, HIGH);
    delayMicroseconds(1);
    uint8_t b = digitalRead(PIN_DOUT);
    digitalWrite(PIN_SCK, LOW);
    interrupts();
    if (i < 24) v = (v << 1) | (b ? 1UL : 0UL);
  }
  if (v & 0x800000UL) v |= 0xFF000000UL;     // sign-extend 24 -> 32 bit
  return (long)v;
}

bool hxAverage(uint8_t n, long &out) {
  long sum = 0;
  for (uint8_t i = 0; i < n; i++) {
    if (!hxWait(READY_TIMEOUT_MS)) {
      Serial.println(F("# ERR no data from HX711 (check wiring)"));
      return false;
    }
    sum += hxRead();
  }
  out = sum / n;
  return true;
}

void updateClock() {
  uint32_t now = micros();
  tMicros += now - lastMicros;
  lastMicros = now;
  while (tMicros >= 1000000UL) { tMicros -= 1000000UL; tSec++; }
}

void printClock() {                          // seconds with 4 decimals
  uint32_t frac = tMicros / 100;
  Serial.print(tSec);
  Serial.print('.');
  for (uint32_t d = 1000; d > 1 && frac < d; d /= 10) Serial.print('0');
  Serial.print(frac);
}

// Least-squares line through the calibration points: grams = slope * (raw - calRaw[0]) + intercept.
// Only the slope is kept; the zero comes from tare.
bool fitLine(float &slope, float &intercept) {
  if (calCount < 2) return false;
  float xm = 0, ym = 0, sxx = 0, sxy = 0;
  for (uint8_t i = 0; i < calCount; i++) {
    xm += (float)(calRaw[i] - calRaw[0]);
    ym += calGrams[i];
  }
  xm /= calCount;
  ym /= calCount;
  for (uint8_t i = 0; i < calCount; i++) {
    float dx = (float)(calRaw[i] - calRaw[0]) - xm;
    sxx += dx * dx;
    sxy += dx * (calGrams[i] - ym);
  }
  if (sxx < 1.0f) return false;
  slope = sxy / sxx;
  intercept = ym - slope * xm;
  return true;
}

void printCal() {
  float slope, icpt, span = 0, worst = 0;
  bool ok = fitLine(slope, icpt);
  Serial.print(F("# cal points: "));
  Serial.println(calCount);
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
      worst = max(worst, (float)fabs(res));
      span = max(span, (float)fabs(calGrams[i]));
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
  if (gramsPerCount != 0) Serial.println(gramsPerCount, 7);
  else Serial.println(F("none (not calibrated)"));
}

void doTare() {
  Serial.println(F("# taring, keep the rig still"));
  if (!hxAverage(AVG_N, tareRaw)) return;
  Serial.print(F("# tare raw "));
  Serial.println(tareRaw);
}

void addPoint(float grams) {
  if (calCount >= MAX_POINTS) {
    Serial.println(F("# ERR point table full, send x to clear"));
    return;
  }
  long r;
  if (!hxAverage(AVG_N, r)) return;
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
  Saved s = { EEPROM_MAGIC, gramsPerCount };
  EEPROM.put(0, s);
  Serial.print(F("# saved g_per_count "));
  Serial.println(gramsPerCount, 7);
}

void measureRate() {
  const uint8_t n = 160;
  long dummy;
  if (!hxAverage(1, dummy)) return;          // line up on a conversion edge
  uint32_t t0 = micros();
  for (uint8_t i = 0; i < n; i++) {
    if (!hxWait(READY_TIMEOUT_MS)) {
      Serial.println(F("# ERR HX711 stopped answering"));
      return;
    }
    hxRead();
  }
  Serial.print(F("# sample rate "));
  Serial.print(1.0e6f * n / (float)(micros() - t0), 1);
  Serial.println(F(" Hz (about 80 with the RATE jumper cut, about 10 if not)"));
}

void printHelp() {
  Serial.println(F("# t tare | c <grams> add cal point | p print cal | s save cal | x clear points"));
  Serial.println(F("# g start stream | h stop stream | m mark | r sample rate | ? help"));
}

void printHeader() {
  Serial.println(F("t_s,raw,grams,mark"));
}

void handleLine() {
  if (lineLen == 0) return;
  lineBuf[lineLen] = '\0';
  lineLen = 0;
  const char *arg = lineBuf + 1;
  while (*arg == ' ') arg++;
  switch (lineBuf[0]) {
    case 't': doTare(); break;
    case 'c':
      if (*arg == '\0') Serial.println(F("# ERR give the mass in grams, e.g. c 500"));
      else addPoint(atof(arg));
      break;
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
}

void pollSerial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n' || ch == '\r') handleLine();
    else if (lineLen < sizeof(lineBuf) - 1) lineBuf[lineLen++] = ch;
  }
}

void setup() {
  pinMode(PIN_DOUT, INPUT);
  pinMode(PIN_SCK, OUTPUT);
  digitalWrite(PIN_SCK, LOW);
  Serial.begin(BAUD);

  Saved s;
  EEPROM.get(0, s);
  if (s.magic == EEPROM_MAGIC && s.gramsPerCount == s.gramsPerCount) gramsPerCount = s.gramsPerCount;

  Serial.println(F("# SpeedUAS thrust stand logger"));
  Serial.print(F("# g_per_count "));
  if (gramsPerCount != 0) Serial.println(gramsPerCount, 7);
  else Serial.println(F("none (not calibrated, grams column is nan)"));
  printHelp();

  delay(500);                                // HX711 settle time after power-up
  doTare();                                  // the Nano resets when the port opens, so this runs every session
  lastMicros = micros();
  printHeader();
}

void loop() {
  pollSerial();
  if (digitalRead(PIN_DOUT) == HIGH) return; // no new conversion yet

  updateClock();
  long raw = hxRead();
  if (!streaming) return;

  printClock();
  Serial.print(',');
  Serial.print(raw);
  Serial.print(',');
  if (gramsPerCount != 0) Serial.print(gramsPerCount * (float)(raw - tareRaw), 2);
  else Serial.print(F("nan"));
  Serial.print(',');
  Serial.println(mark);
}
