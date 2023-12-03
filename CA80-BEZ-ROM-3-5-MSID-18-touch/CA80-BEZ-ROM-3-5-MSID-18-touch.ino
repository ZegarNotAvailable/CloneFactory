// ------------------------------------------------------------------------------
//  Program rozruchowy dla Z80 lub Z180 (na podstawie Z80-MBC2)
//  Z180 w przeciwienstwie do Z80 nie jest statyczny...
//  Musialem zmienic sposob komunikacji AVR -> Zilog.
// ------------------------------------------------------------------------------

#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include "Arduino.h"
#include "z80-disassembler.h"
#include "mpr121.h"

#define VER ".3.5.18"  // For info
#define CR 0xd                          // ASCII CR for GH CR-LF issue
#define RC2014 1                        // 1 - RC2014, 0 - CA80mini
#define TOUCH 1                         // 1 - with touch, 0 - without
//#define Z180                          // Zakomentuj jesli Z80
//#define DEBUG
// ------------------------------------------------------------------------------
//  Stale klawiatury
// ------------------------------------------------------------------------------

#define PCF_KBD    0x38     //Adres PCF8574A 0x38 , dla PCF8574 0x20

#define WAIT_EN      11    // PD3 pin 17   
#define MAXDATALENGTH 5
//definicje SD
#define FILES_NUMBER 5
#define NAME_WIDTH 9
#define EXTENSION String(".HEX")
#define SD_CS  4           // PB4 pin 5    SD SPI
File myFile;
byte cpuMode;
char inChar;                                  // Input char from serial
byte namesNumber;
char fileNames[FILES_NUMBER][NAME_WIDTH];
String fileName = "ca80.txt";
byte CA80_REGS[25];                           // For Z80 registers
byte CA80_PROG_MEM[33];                       // For Z80 program memory
byte CA80_DATA_MEM[12] =                      // Pointed by HL
{
  'A', 'l', 'a', ' ', 'm', 'a', ' ', 'k', 'o', 't', 'a'
};
byte CA80_DISP_MEM[9] =
{
  0xbf, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07
};
byte CA80_STACK_MEM[17];
byte newData = 0;                             // For Z80 registers
byte data[] = {0x01, 0x02, 0x03, 0x04, 0x05}; // For disassembler
byte timeout = 0;
byte CA80r = 0;

// ------------------------------------------------------------------------------
//
// Hardware definitions like(Z80-MBC2)
//
// ------------------------------------------------------------------------------

#define   D0            24    // PA0 pin 40   Z80 data bus
#define   D1            25    // PA1 pin 39
#define   D2            26    // PA2 pin 38
#define   D3            27    // PA3 pin 37
#define   D4            28    // PA4 pin 36
#define   D5            29    // PA5 pin 35
#define   D6            30    // PA6 pin 34
#define   D7            31    // PA7 pin 33

#define   AD0           18    // PC2 pin 24   Z80 A0
#define   RD_           19    // PC3 pin 25   Z80 RD
#define   WR_           20    // PC4 pin 26   Z80 WR
#define   RESET_        22    // PC6 pin 28   Z80 RESET
#define   irqPin        23    // PC7 pin 29   MPR121
#define   SNMI          10    // PD2 pin 16   SNMI potrzebne w oryginalnym "starym" CA80
#define   NMI           12    // PD4 pin 18   NMI generowane przez TIMER1 - w "starym" CA80 zbędne
#define   INT_           1    // PB1 pin 2    Z80 control bus
#define   MEM_EN_        2    // PB2 pin 3    RAM Chip Enable (CE2). Active HIGH. Used only during boot
#define   WAIT_          3    // PB3 pin 4    Z80 WAIT Na płytce z ATmegą QFP niepodłączone!!!
#define   MOSI           5    // PB5 pin 6    SD SPI
#define   MISO           6    // PB6 pin 7    SD SPI
#define   SCK            7    // PB7 pin 8    SD SPI
#define   BUSREQ_       14    // PD6 pin 20   Z80 BUSRQ
#define   CLK           15    // PD7 pin 21   Z80 CLK
#define   SCL_PC0       16    // PC0 pin 22   (I2C)
#define   SDA_PC1       17    // PC1 pin 23   (I2C)
#define   LED_IOS        0    // PB0 pin 1    Led LED_IOS is ON if HIGH - Niepodłączone
#define   WAIT_RES_      0    // PB0 pin 1    Reset the Wait FF         - j. w.
#define   USER          13    // PD5 pin 19   Led USER and key (led USER is ON if LOW) Brak LED
#define   DS3231_RTC    0x68  // DS3231 I2C address
#define   DS3231_SECRG  0x00  // DS3231 Seconds Register
#define   DS3231_STATRG 0x0F  // DS3231 Status Register
#define   FAST_CLK      0     // 8 MHz
#define   SLOW_CLK      1     // 4 MHz
// ------------------------------------------------------------------------------
//
//  Constants
//
// ------------------------------------------------------------------------------

const byte    LD_HL        =  0x36;       // Opcode of the Z80 instruction: LD(HL), n
const byte    INC_HL       =  0x23;       // Opcode of the Z80 instruction: INC HL
const byte    LD_HLnn      =  0x21;       // Opcode of the Z80 instruction: LD HL, nn
const byte    JP_HL        =  0xE9;       // Opcode of the Z80 instruction: JP (HL)
const word    CA80_SEC     = 0xFFED;      // Zegar CA80
const word    CA_START     = 0x0270;      // CA80 RESTA - back to monitor

// DS3231 RTC variables
byte     foundRTC = 1;                   // Set to 1 if RTC is found, 0 otherwise
//seconds, minutes, hours, dayOfWeek, day, month, year;
byte          time[7];

void loadHL(word value);
void loadByteToRAM(byte value);
void receiveRegs();
void receivePrMem();
void printFullByte(byte b);
void printFullWord(word w);
void showRegs();
void showFirstLine();
void showSecondLine();
void showConditions(byte c);
void waitResume();

const byte routLen = 6;
const char CA80rtn[] PROGMEM =
{
  "RESTA "
  "COM   "
  "COM1  "
  "CLR   "
  "CLR1  "
  "PRINT "
  "PRINT1"
  "CO    "
  "CO1   "
  "LBYTE "
  "LBYTE1"
  "LADR  "
  "LADR1 "
  "CZAS  "
  "CSTS  "
  "CI    "
  "TI    "
  "TI1   "
  "PARAM "
  "PARAM1"
  "PARA1 "
  "EXPR  "
  "EXPR1 "
  "HILO  "
  "USPWYS"
  "FMAG  "
};


void sendNop(int NOPsToSend)
{
  for (int i = 0; i < NOPsToSend; i++)
  {
    sendDataBus(0);     //Z80 NOP
  }
}

void readRTC()
// Read current date/time binary values from the DS3231 RTC
{
  Wire.beginTransmission(DS3231_RTC);
  Wire.write(DS3231_SECRG);                       // Set the DS3231 Seconds Register
  if (Wire.endTransmission() != 0)
  {
    foundRTC = 0;
    Serial.println(F("RTC not found."));
    return;      // RTC not found
  }
  // Read from RTC
  Wire.requestFrom(DS3231_RTC, 7);
  for (byte i = 0; i < 7; i++)
  {
    time[i] = Wire.read();
  }
  dayOfWeek();
}

void dayOfWeek()
{
  const byte CA80dayOfWeek[] = {1, 7, 6, 5, 4, 3, 2}; //w CA80 poniedziałek ma wartość "7" a niedziela "1".
  uint16_t y = (((time[6] / 16) * 10 + (time[6] & 15)) + 2000); // w RTC są tylko dwie cyfry w BCD
  byte m = ((time[5] / 16) * 10 + (time[5] & 15));
  byte d = ((time[4] / 16) * 10 + (time[4] & 15));
  const int t[] = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 };
  y -= m < 3;
  time[3] = (CA80dayOfWeek[ (y + y / 4 - y / 100 + y / 400 + t[m - 1] + d) % 7]);
}

void sendTime()
{
  sendNop(4);
  loadHL(CA80_SEC);                   // Set Z80 HL = SEC (used as pointer to RAM);
  for (byte i = 0; i < 7; i++)
  {
    loadByteToRAM(time[i]);         // Write current data byte into RAM
  }
}

void readFile(String fileName)
{
  Serial.println(F("Initializing SD card..."));
  delay(200);
  if (!SD.begin(SD_CS))
  {
    Serial.println(F("initialization failed!"));
    return;
  }
  Serial.println(F("initialization done."));
  if (SD.exists(fileName))
  {
    Serial.print(fileName);
    Serial.println(F(" exists."));
  }
  else
  {
    Serial.print(fileName);
    Serial.println(F(" doesn't exist."));
  }
  myFile = SD.open(fileName); // re-open the file for reading:
  if (myFile)
  {
    namesNumber = 1;
    byte i, j;
    char c;
    for (j = 0; j < FILES_NUMBER; j++)
    {
      for (i = 0; i < NAME_WIDTH; i++)
      {
        if (myFile.available())// read from the file until there's nothing else in it
        {
          c = (myFile.read());
          Serial.print(c);
          if ((c < '0') || (c > 'z'))
          {
            if (c == ' ')
            {
              if (i == 0)
              {
                Serial.println(F("Name is to short!"));
                return;
              }
              else
              {
                fileNames[j][i] = '\0';
                i = NAME_WIDTH;
                namesNumber++;
              }
            }
          }
          else
          {
            fileNames[j][i] = c;
          }
        }
        else
        {
          Serial.println(F("\r\n* End of file *"));
          myFile.close();
          return;
        }
      }
    }
  }
}

void sendFilesFromSD()
{
  byte j;
  Serial.println();
  sendNop(4);
  for (j = 0; j < namesNumber; j++)
  {
    fileName = String(String(fileNames[j]) + EXTENSION);
    if (SD.exists(fileName))
    {
      Serial.print(F("Loading "));
      Serial.println(fileName);
      sendNop(4);
      sendFileFromSD(fileName);
    }
    else
    {
      Serial.print(fileName);
      Serial.println(F(" doesn't exist."));
    }
  }
}

void sendRecord()
{
  if (myFile.available())
  {
    byte i = getByteFromFile();
    word adr = getAdrFromFile();
    byte typ = getByteFromFile();
    if (typ == 0)
    {
      sendDataToCA80(i, adr);
    }
    else
    {
      Serial.print(F("End of file: "));
      Serial.println(fileName);
    }
    getByteFromFile();          // (suma) zakladam, ze plik jest poprawny i nie sprawdzam sumy
    // ale trzeba ja przeczytac!!!
    if (CR == myFile.read())    // tak jak znaki CR (jezeli sa)
    {
      myFile.read();            // i LF na koncu rekordu :-)
    }
  }
}

byte getByteFromFile()
{
  byte h = 0, l = 0;
  h = getDigitFromFile();
  l = getDigitFromFile();
  return ((16 * h) + l);
}

byte getDigitFromFile()
{
  byte d = 0;
  if (myFile.available())
  {
    d = myFile.read();
    d = asciiToDigit(d);
  }
  return d;
}

byte asciiToDigit(byte l)
{
  l = l - 0x30;
  if (l > 0x09)
  {
    l = l - 0x07;
  }
  return l;
}

word getAdrFromFile()
{
  byte h = getByteFromFile();
  byte l = getByteFromFile();
  return ((256 * h) + l);
}

void sendDataToCA80(byte l, word adr)  //l - liczba bajtow do przeslania, adr - adres pierwszego bajtu
{
  loadHL(adr);                   // Set Z80 HL = SEC (used as pointer to RAM);
  for (byte i = 0; i < l; i++)
  {
    byte b = getByteFromFile();
    loadByteToRAM(b);         // Write current data byte into RAM (adr w HL, HL++),
  }
}

void sendFileFromSD(String fileName)
{
  myFile = SD.open(fileName); // re-open the file for reading:
  if (myFile)
  {
    while (myFile.available())// read from the file until there's nothing else in it
    {
      byte c = (myFile.read());
      if (c  == 0x3a)
      {
        sendRecord();
      }
      else
      {
        Serial.print(F("Wrong format file: "));
        Serial.println(fileName);
        myFile.close();
        return;
      }
    }
    myFile.close();
  }
}

void loadFile()
{
  fileName = "user.txt";
  readFile(fileName);
  byte j;
  Serial.println();
  for (j = 0; j < namesNumber; j++)
  {
    fileName = String(String(fileNames[j]) + EXTENSION);
    Serial.println(fileName);
    Serial.print(F("Do you want to load this file? < [Y/N] >"));
    do
    {
      inChar = Serial.read();
    }
    while ((inChar != 'y') && (inChar != 'Y') && (inChar != 'n') && (inChar != 'N'));
    Serial.println(inChar);
    if ((inChar == 'y') || (inChar == 'Y'))
    {
      if (SD.exists(fileName))
      {
        Serial.print(F("Loading "));
        setTransferMode(1);
        sendFileFromSD(fileName);
        setTransferMode(0);
      }
      else
      {
        Serial.print(fileName);
        Serial.println(F(" doesn't exist."));
      }
    }
  }
}

void setTransferMode(byte m)
{
  if (m)
  {
    cpuMode = 1;
    pinMode(NMI, INPUT_PULLUP);                           // PD4 jako wejscie
    delay(1);                                             // NMI OFF
    digitalWrite(WAIT_EN, HIGH);
    sendNop(4);
  }
  else
  {
    if (cpuMode)
    {
      cpuMode = 0;
      sendNop(4);
      loadHL(CA_START);
      digitalWrite(WAIT_EN, LOW);
      sendDataBus(JP_HL);                                 // CA80 MONITOR
      delay(1);                                           // NMI ON
      pinMode(NMI, OUTPUT);                               // PD4 jako wyjscie
    }
  }
}

void setCLK(byte mode)
{
  // Initialize CLK @ 8MHz (@ Fosc = 16MHz). Z80 clock_freq = (Atmega_clock) / ((OCR2 + 1) * 2)
  ASSR &= ~(1 << AS2);                            // Set Timer2 clock from system clock
  TCCR2 |= (1 << CS20);                           // Set Timer2 clock to "no prescaling"
  TCCR2 &= ~((1 << CS21) | (1 << CS22));
  TCCR2 |= (1 << WGM21);                          // Set Timer2 CTC mode
  TCCR2 &= ~(1 << WGM20);
  TCCR2 |= (1 <<  COM20);                         // Set "toggle OC2 on compare match"
  TCCR2 &= ~(1 << COM21);
  OCR2 = mode;                                    // Set the compare value to toggle OC2 (1 = 4 MHz or 0 = 8 MHz)
  pinMode(CLK, OUTPUT);                           // Set OC2 as output and start to output the clock
  Serial.print(F("Z80 is running from now at "));
  if (mode) Serial.println(F("4 MHz."));
  else Serial.println(F("8 MHz."));

  Serial.println();
}

void  setNMI()
{
  // TIMER1 ustawiamy na 1000 Hz (toggle, więc na wyjściu NMI będzie 500 Hz)
  TCCR1A = 0;                                     // zerujemy TCCR1A
  TCCR1A |= (1 << COM1B0) | (1 << FOC1B);         // PD4 500 Hz NMI
  TCCR1B = 0;                                     // zerujemy TCCR1B
  TCNT1  = 0;                                     // zerujemy licznik
  //  1000 Hz
  OCR1A = 15999; // = 16000000 / (1 * 1000) - 1 (must be <65536)
  OCR1B = 15000; // wartosc prawie dowolna
  // CTC mode
  TCCR1B |= (1 << WGM12);
  // ustawiamy prescaler
  TCCR1B |= (0 << CS12) | (0 << CS11) | (1 << CS10);
  pinMode(NMI, OUTPUT);                           // PD4 jako wyjscie
  // enable timer compare interrupt
  TIMSK |= (1 << OCIE1A);
  sei();//allow interrupts
}

ISR(TIMER1_COMPA_vect)
{ //timer1 interrupt 1kHz countdown timeout
  if (timeout)
  {
    timeout--;
  }
}

void setup()
{
  // ------------------------------------------------------------------------------

  Wire.begin();                                   // Wake up I2C bus
  Serial.begin(115200);
  Serial.print(F("CA80 loader with simple-MSid "));
  if (RC2014)
  {
    Serial.print(F("for RCbus"));
  }
  else
  {
    Serial.print(F("for CA80-mini"));
  }
  if (TOUCH)
  {
    Serial.print(F(" with touch"));
  }
  Serial.println(F(VER));
  pinsSetings();
  Serial.println(F("Loading..."));
  readFile(fileName);
  sendFilesFromSD();
  Serial.println(F("Real time setting..."));
  readRTC();
  sendTime();
  showTime();
  Serial.println(F("* Done. *\r\n"));
  digitalWrite(USER, HIGH);
  // ----------------------------------------
  // Z80 BOOT
  // ----------------------------------------

#ifdef Z180

  setCLK(FAST_CLK);                               // jeżeli Z180 CLK = 8 MHz

#endif

  resetCPU();
  setNMI();                                       // NMI = 500 Hz

  //digitalWrite(SNMI, LOW);                      // Odblokowanie NMI i INT w oryginalnym CA80
}

// ------------------------------------------------------------------------------


void loop()
{
  if (!digitalRead(WAIT_))
  {
    if (!digitalRead(WR_))
    {
      if (RC2014 ^ !digitalRead(AD0))               // Read Z80 address bus line AD0 (PC2)
      {
        byte command = PINA; // Read Z80 data bus D0-D7 (PA0-PA7)
        waitResume();
        //Serial.println(command, HEX);
        switch (command)
        {
          case 'R':
            receiveRegs();
            break;
          case 'P':
            receivePrMem();
            newData = 1;
            break;
          case 'S':
            receiveStackMem();
            break;
          case 'D':
            receiveDispMem();
            break;
          case 'T':
            setDS3231();
            break;
          case 'H':
            receiveDataMem();
            break;
        }
      }
      else
      {
        waitResume();
      }
    }
  }
  if ( newData )
  {
    Serial.println();
    showConditions(4);
    showFirstLine();
    showConditions(16);
    showSecondLine();
    newData = 0;
  }
#if (TOUCH == 1)
  if (!digitalRead(irqPin))
  {
    czytajKlawiature();
  }
#endif
  if (Serial.available())
  {
    char k = Serial.read();
    Serial.write(k);
    switch (k)
    {
      case 'L':
        listing();
        break;
      case 'P':
        showDisplay(CA80_DATA_MEM);
        break;
      case 'W':
        showDisplay(CA80_DISP_MEM);
        break;
      case 'S':
        showStack();
        break;
      case 'H':
        showHLdata();
        break;
      case 'R':
        loadFile();
        break;
      default:
        sendKeyCode(k);
        delay(100);
        sendKeyCode('-');
        delay(100);
        break;
    }
  }
}
// ------------------------------------------------------------------------------
// MikSid routines
// ------------------------------------------------------------------------------

void wait(byte tout)
{
  timeout = tout;
  bool w;
  do
  {
    w = (digitalRead(WAIT_));
  } while (w && timeout);
}

void receiveRegs()
{
  byte b = 0;
  for ( byte i = 0; i < 24; i++)
  {
    wait(10);
    b = PINA;
    waitResume();
    CA80_REGS[i] = b;
  }
#ifdef DEBUG

  showRegs();

#endif  //DEBUG
}

void receivePrMem()
{
  byte b = 0;
  for ( byte i = 0; i < 32; i++)
  {
    wait(10);
    b = PINA;
    waitResume();
    CA80_PROG_MEM[i] = b;
  }
}

void receiveDataMem()
{
  byte b = 0;
  for ( byte i = 0; i < 12; i++)
  {
    wait(10);
    b = PINA;
    waitResume();
    CA80_DATA_MEM[i] = b;
  }
}

void receiveStackMem()
{
  byte b = 0;
  for ( byte i = 0; i < 16; i++)
  {
    wait(10);
    b = PINA;
    waitResume();
    CA80_STACK_MEM[i] = b;
  }
}

void receiveDispMem()
{
  byte b = 0;
  for ( byte i = 0; i < 8; i++)
  {
    wait(10);
    b = PINA;
    waitResume();
    CA80_DISP_MEM[(7 - i)] = b;
  }
}

void setDS3231()
{
  for ( byte i = 0; i < 7; i++)
  {
    wait(10);
    time[i] = PINA;
    waitResume();
  }
  showTime();
  if (foundRTC)
  {
    Wire.beginTransmission(DS3231_RTC);
    Wire.write(DS3231_SECRG);                       // Set the DS3231 Seconds Register
    for ( byte i = 0; i < 7; i++)
    {
      Wire.write(time[i]);
    }
    Wire.endTransmission();
    // Read the "Oscillator Stop Flag"
    Wire.beginTransmission(DS3231_RTC);
    Wire.write(DS3231_STATRG);                      // Set the DS3231 Status Register
    Wire.endTransmission();
    Wire.requestFrom(DS3231_RTC, 1);
    byte    OscStopFlag;
    OscStopFlag = Wire.read() & 0x80;               // Read the "Oscillator Stop Flag"
    if (OscStopFlag)
    {
      // Reset the "Oscillator Stop Flag"
      Wire.beginTransmission(DS3231_RTC);
      Wire.write(DS3231_STATRG);                    // Set the DS3231 Status Register
      Wire.write(0x08);                             // Reset the "Oscillator Stop Flag" (32KHz output left enabled)
      Wire.endTransmission();
    }
  }
}

void showTime()
{
  Serial.println();
  for (uint8_t i = 0; i < 7; i++)
  {
    printFullByte(time[6 - i]);
    Serial.write('/');
  }
  Serial.println();
}

void showStack()
{
  Serial.println();
  for (uint8_t i = 0; i < 16; i += 2)
  {
    printFullByte(CA80_STACK_MEM[i + 1]);
    printFullByte(CA80_STACK_MEM[i]);
    Serial.write(' ');
  }
  Serial.println();
}

void showHLdata()
{
  Serial.println();
  word hl = reg16(12);    //HL
  byte memHL;
  for (uint8_t i = 0; i < 11; i++)
  {
    printFullWord(hl);
    hl++;
    Serial.write(' ');
    memHL = CA80_DATA_MEM[i];
    if ((memHL > 20) && (memHL <= 'z'))
    {
      Serial.write(memHL);
    }
    else
    {
      Serial.write(' ');
    }
    Serial.write(' ');
    printFullByte(memHL);
    Serial.print(F(": "));
    printByteBin(memHL);
    Serial.println();
  }
}

void printByteBin(byte bin)
{
  char b;
  for (uint8_t i = 0; i < 8; i++)
  {
    b = (bin & (1 << (7 - i))) ? '1' : '0';
    Serial.write(b);
  }
}

void showDisplay(byte * buf)
{
  //    " 7    6    5    4    3    2    1    0 \r\n"
  //    "      _         _    _         _    _ \r\n"
  //    "     | |    |   _|   _|  |_|  |_   |_ \r\n"
  //    "     |_|    |  |_    _|    |   _|  |_|\r\n"
  //
  // CA80_DISP_MEM[] - bufor z danymi do wyświetlenia "W"
  // CA80_DATA_MEM[] - bufor z danymi do wyświetlenia "P"

  Serial.println();
  Serial.print(F(" 7    6    5    4    3    2    1    0 \r\n"));
  virtualDisplay(buf);
}

void virtualDisplay(byte * buf)
{
  const char empty[] PROGMEM = ("                                       \r\n");
  char  row1[sizeof(empty)];                       // For display
  char  row2[sizeof(empty)];
  char  row3[sizeof(empty)];
  for (uint8_t i = 0; i < sizeof(empty); i++)
  {
    row1[i] = empty[i];                       // For display
    row2[i] = empty[i];
    row3[i] = empty[i];
  }
  const uint8_t d[]PROGMEM =    // displacement
  {
    1, 2, 2, 1, 0, 0, 1, 3
  };
  const char segment[]PROGMEM =    // 7 segment display
  {
    "_||_||_."
  };
  for (uint8_t i = 0; i < 8; i++)             // digit
  {
    for (uint8_t j = 0; j < 8; j++)           // segment
    {
      if (buf[i] & (1 << j))
      {
        switch (j)
        {
          case 0:                             // segment a
            row1[i * 5 + d[j]] = segment[j];
            break;
          case 1:                             // segment b
          case 5:                             // segment f
          case 6:                             // segment g
            row2[i * 5 + d[j]] = segment[j];
            break;
          default:                             // segment c,d,e or k
            row3[i * 5 + d[j]] = segment[j];
        }
      }
    }
  }
  Serial.print(row1);
  Serial.print(row2);
  Serial.print(row3);
}

void showRegs()
{
  const char regZ80[]PROGMEM = ("DEBCAFIXIYSPHLPCA'B'D'H'");
  Serial.println();
  for ( byte i = 0; i < 24; i++)
  {
    if (i == 12) Serial.println();
    Serial.write(regZ80[i]);
    byte regL = CA80_REGS[i];
    i++;
    Serial.write(regZ80[i]);
    byte regH = CA80_REGS[i];
    word reg = (regH  * 256 ) + regL;
    Serial.print(F(" = "));
    Serial.print(reg, HEX);
    Serial.print(F(", "));
  }
  Serial.println();
}

void printRegister(byte j)
{
  printFullByte(CA80_REGS[j]);
}

void printReg16(byte k)
{
  const char regZ80[]PROGMEM = ("D=B=AFX=Y=S=H=P=A'B'D'H'");
  Serial.print(F(" "));
  Serial.write(regZ80[k]);
  Serial.write(regZ80[(++k)]);
  printRegister(k);
  printRegister(--k);
}

void printFullWord(word w)
{
  printFullByte(w / 256);
  printFullByte(w % 256);
}

void printFullByte(byte b)
{
  if (b < 16)
  {
    Serial.write('0');
  }
  Serial.print(b, HEX);
}

void showFirstLine()
{
  const byte index[] = {2, 0, 12, 10, 14};  //B (BC), D (DE), H (HL), S (SP), P (PC)
  Serial.print(F(" A="));
  printRegister(5);
  for (byte i = 0; i < 5; i++)
  {
    printReg16(index[i]);
  }
  Serial.print(F("   "));
  char buf[20];
  for (byte i = 0; i < MAXDATALENGTH ; i++)
  {
    data[i] = CA80_PROG_MEM[i];
  }
  int bytesUsed = Z80Disassembler::disassemble(buf, data, MAXDATALENGTH);//dataLength);
  for (byte i = 0; i < bytesUsed; i++)
  {
    printFullByte(data[i]);
  }
  for (byte i = 0; i < (7 - ( 2 * bytesUsed)); i++)
  {
    Serial.write(' ');
  }
  byte indexRt = isCA80routine(buf, data);
  Serial.write((CA80r) ? 'S' : ' ');
  Serial.write(' ');
  Serial.print(buf);
  if (CA80r > 0)
  {
    printSystemRoutine(buf, indexRt);
    CA80r--;
    if (CA80r > 0)
    {
      CA80r = bytesUsed;
    }
  }
  Serial.println();
}

void printSystemRoutine(char* buf, byte index)
{
  for (byte i = 0; i < routLen; i++)
  {
    buf[i] = pgm_read_byte_near(CA80rtn + ((index * routLen) + i));
  }
  buf[routLen] = '\0';
  Serial.print(buf);
}

byte isCA80routine(char* buf, byte * opcode)
{
  byte index = 0;
  CA80r = 0;
  switch (opcode[0])
  {
    case 0xd7:
      CA80r = 2;
      buf[4] = '\0';
      index = 3;  //CLR
      break;
    case 0xdf:
      CA80r = 2;
      buf[4] = '\0';
      index = 9;  //LBYTE
      break;
    case 0xe7:
      CA80r = 2;
      buf[4] = '\0';
      index = 11;   //LADR
      break;
    case 0xcf:
      CA80r = 2;
      buf[4] = '\0';
      index = 17;   //TI1
      break;
    case 0xf7:
      CA80r = 1;
      buf[4] = '\0';
      index = 0;    //RESTA
      break;
    case 0xef:
      CA80r = 1;
      buf[4] = '\0';
      index = 24;    //USPWYS
      break;
    case 0xcd:
      switch (opcode[2])
      {
        case 0x00:
          switch (opcode[1])
          {
            case 0x10:
              CA80r = 2;
              buf[5] = '\0';
              index = 3;    //CLR
              break;
            case 0x11:
              CA80r = 1;
              buf[5] = '\0';
              index = 4;    //CLR1
              break;
            case 0x18:
              CA80r = 2;
              buf[5] = '\0';
              index = 9;    //LBYTE
              break;
            case 0x1b:
              CA80r = 1;
              buf[5] = '\0';
              index = 10;   //LBYTE1
              break;
            case 0x20:
              CA80r = 2;
              buf[5] = '\0';
              index = 11;   //LADR
              break;
            case 0x21:
              CA80r = 1;
              buf[5] = '\0';
              index = 12;   //LADR1
              break;
            case 0x07:
              CA80r = 2;
              buf[5] = '\0';
              index = 16;   //TI
              break;
            case 0x08:
              CA80r = 1;
              buf[5] = '\0';
              index = 17;   //TI1
              break;
            case 0xef:
              CA80r = 1;
              buf[5] = '\0';
              index = 24;   //SPEC
              break;
            default:
              break;
          }
        case 0x01:
          switch (opcode[1])
          {
            case 0xab:
              CA80r = 2;
              buf[5] = '\0';
              index = 1;    //COM
              break;
            case 0xac:
              CA80r = 1;
              buf[5] = '\0';
              index = 2;    //COM1
              break;
            case 0xd4:
              CA80r = 2;
              buf[5] = '\0';
              index = 5;    //PRINT
              break;
            case 0xd5:
              CA80r = 1;
              buf[5] = '\0';
              index = 6;    //PRINT1
              break;
            case 0xe0:
              CA80r = 2;
              buf[5] = '\0';
              index = 7;    //CO
              break;
            case 0xe1:
              CA80r = 1;
              buf[5] = '\0';
              index = 8;    //CO1
              break;
            case 0xf4:
              CA80r = 2;
              buf[5] = '\0';
              index = 18;   //PARAM
              break;
            case 0xf5:
              CA80r = 1;
              buf[5] = '\0';
              index = 19;   //PARAM1
              break;
            case 0xf8:
              CA80r = 1;
              buf[5] = '\0';
              index = 20;   //PARA1
              break;
            default:
              break;
          }
        case 0x02:
          switch (opcode[1])
          {
            case 0x2d:
              CA80r = 1;
              buf[5] = '\0';
              index = 13;    //CZAS
              break;
            case 0x13:
              CA80r = 2;
              buf[5] = '\0';
              index = 21;    //EXPR
              break;
            case 0x14:
              CA80r = 1;
              buf[5] = '\0';
              index = 5;    //EXPR1
              break;
            case 0x3b:
              CA80r = 1;
              buf[5] = '\0';
              index = 23;    //HILO
              break;
            default:
              break;
          }
        case 0x43:
          switch (opcode[1])
          {
            case 0x37:
              CA80r = 1;
              buf[5] = '\0';
              index = 25;    //FMAG
              break;
            default:
              break;
          }
        case 0xff:
          switch (opcode[1])
          {
            case 0xc3:
              CA80r = 1;
              buf[5] = '\0';
              index = 14;    //CSTS
              break;
            case 0xc6:
              CA80r = 1;
              buf[5] = '\0';
              index = 15;    //CI
              break;
            default:
              break;
          }
        default:
          break;
      }
    default:
      break;
  }
  return (index);
}

void showSecondLine()
{
  const byte index[] = {18, 20, 22, 6, 8};  //B' (BC), D' (DE), H' (HL), X (IX), Y (IY)
  Serial.print(F(" A'"));
  printRegister(17);
  for (byte i = 0; i < 5; i++)
  {
    printReg16(index[i]);
  }
  Serial.print(F("  "));
  if (CA80r > 0)
  {
    printPWYS(CA80_PROG_MEM[CA80r]);
  }
  Serial.println();
}


void showConditions(byte c)
{
  byte condition = CA80_REGS[c];
  for (int i = 7; i > -1; i--)
  {
    if (i != 5 && i != 3)
    {
      if (condition & 1 << i)
      {
        Serial.write("SZxHxPNC"[(7 - i)]);
      }
      else
      {
        Serial.write('-');
      }
    }
  }
}

#define PC_ 14
#define SP_ 10
#define HL_ 12

word reg16(byte reg)
{
  return (CA80_REGS[reg] + (256 * CA80_REGS[(reg + 1)]));  //
}

void listing()
{
  Serial.println();
  byte ptr = 0;
  word pc = reg16(PC_);
  char buf[20];
  for (byte l = 0; l < 11; l++)
  {
    printFullWord(pc);
    Serial.write(' ');
    for (byte i = 0; i < MAXDATALENGTH ; i++)
    {
      data[i] = CA80_PROG_MEM[(i + ptr)];
    }
    int bytesUsed = Z80Disassembler::disassemble(buf, data, MAXDATALENGTH);//dataLength);
    ptr += bytesUsed;
    pc += bytesUsed;
    for (byte i = 0; i < bytesUsed; i++)
    {
      printFullByte(data[i]);
    }
    for (byte i = 0; i < (9 - ( 2 * bytesUsed)); i++)
    {
      Serial.write(' ');
    }
    byte indexRt = isCA80routine(buf, data);
    Serial.write((CA80r > 0) ? 'S' : ' ');
    Serial.write(' ');
    Serial.print(buf);
    if (CA80r > 0)
    {
      printSystemRoutine(buf, indexRt);
    }
    Serial.println();
    if (CA80r > 1)
    {
      printFullWord(pc);
      printPWYS(CA80_PROG_MEM[ptr]);
      pc++;
      ptr++;
      l++;
    }
  }
}

void printPWYS(byte PWYS)
{
  Serial.write(' ');
  printFullByte(PWYS);
  Serial.print(F("         DB "));
  printFullByte(PWYS);
  Serial.println(F(" ;PWYS"));
}

// ------------------------------------------------------------------------------

// Z80 bootstrap routines

// ------------------------------------------------------------------------------

#define WAIT_RES_HIGH   PORTB |= B00000001
#define WAIT_RES_LOW    PORTB &= B11111110
#define BUSREQ_HIGH     PORTD |= B01000000
#define BUSREQ_LOW      PORTD &= B10111111
#define MEM_EN_HIGH     PORTB |= B00000100
#define MEM_EN_LOW      PORTB &= B11111011
#define TEST_RD         PINC & B00001000  //PC3

void waitResume()
{
  BUSREQ_LOW;                         // Request for a DMA
  WAIT_RES_LOW;                       // Now is safe reset WAIT FF (exiting from WAIT state)
  delayMicroseconds(2);               // Wait 2us
  WAIT_RES_HIGH;
  BUSREQ_HIGH;                        // Resume Z80 from DMA
}

void waitRD()
{
  bool test;
  do
  {
    test = (PINC & B00001000);
  }
  while (test);
}

void ramEN()
{
  DDRA = 0x00;                        // Configure Z80 data bus D0-D7 (PA0-PA7) as input...
  PORTA = 0xFF;                       // ...with pull-up
  MEM_EN_HIGH;
}

void sendDataBus(byte data)
{
  waitRD();
  MEM_EN_LOW;                         // Force the RAM in HiZ (CE2 = LOW)
  DDRA = 0xFF;                        // Configure Z80 data bus D0-D7 (PA0-PA7) as output
  PORTA = data;                       // Write data on data bus
  BUSREQ_LOW;                         // Request for a DMA
  WAIT_RES_LOW;                       // Now is safe reset WAIT FF (exiting from WAIT state)
  delayMicroseconds(2);               // Wait 2us just to be sure that Z80 read the data and go HiZ
  WAIT_RES_HIGH;
  ramEN();
  BUSREQ_HIGH;                        // Resume Z80 from DMA
}

void loadByteToRAM(byte value)
// Load a given byte to RAM using a sequence of two Z80 instructions forced on the data bus.
// The MEM_EN_ signal is used to force the RAM in HiZ, so the Atmega can write the needed instruction/data
//  on the data bus.
// The two instruction are "LD (HL), n" and "INC (HL)".
{

  // Execute the LD(HL),n instruction (T = 3+3+3). See the Z80 datasheet and manual.
  // After the execution of this instruction the <value> byte is loaded in the memory address pointed by HL.
  sendDataBus(LD_HL);
  sendDataBus(value);                      // Write the byte to load in RAM on data bus
  sendDataBus(INC_HL);                     // Write "INC HL" opcode on data bus
}

// ------------------------------------------------------------------------------

void loadHL(word value)
// Load "value" word into the HL registers inside the Z80 CPU, using the "LD HL,nn" instruction.
// In the following "T" are the T-cycles of the Z80 (See the Z80 datashet).
{
  // Execute the LD dd,nn instruction (T = 4+3+3), with dd = HL and nn = value. See the Z80 datasheet and manual.
  // After the execution of this instruction the word "value" (16bit) is loaded into HL.
  sendDataBus(LD_HLnn);                    // Write "LD HL, n" opcode on data bus
  sendDataBus(lowByte(value));             // Write first byte of "value" to load in HL
  sendDataBus(highByte(value));            // Write second byte of "value" to load in HL
}

void pinsSetings()
{
  // ----------------------------------------
  // INITIALIZATION
  // ----------------------------------------

  // Initialize RESET_ and WAIT_RES_
  pinMode(RESET_, OUTPUT);                        // Configure RESET_ and set it ACTIVE
  digitalWrite(RESET_, LOW);
  pinMode(WAIT_RES_, OUTPUT);                     // Configure WAIT_RES_ and set it ACTIVE to reset the WAIT FF (U1C/D)
  digitalWrite(WAIT_RES_, LOW);
  pinMode(WAIT_EN, OUTPUT);                       // Configure WAIT_EN and set it ACTIVE
  digitalWrite(WAIT_EN, HIGH);

  pinMode(USER, INPUT_PULLUP);                    // Read USER Key

  // Initialize USER,  INT_, MEM_EN_, and BUSREQ_
  pinMode(USER, OUTPUT);                          // USER led OFF
  digitalWrite(USER, HIGH);
  pinMode(INT_, INPUT_PULLUP);                    // Configure INT_ and set it NOT ACTIVE
  //pinMode(INT_, OUTPUT);                        // Z80 CTC conflict !!!
  //digitalWrite(INT_, HIGH);
  pinMode(MEM_EN_, OUTPUT);                       // Configure MEM_EN_ as output
  digitalWrite(MEM_EN_, HIGH);                    // Set MEM_EN_ HZ
  pinMode(BUSREQ_, INPUT_PULLUP);                 // Set BUSREQ_ HIGH
  pinMode(BUSREQ_, OUTPUT);
  digitalWrite(BUSREQ_, HIGH);

  // Initialize D0-D7, AD0, MREQ_, RD_ and WR_
  DDRA = 0x00;                                    // Configure Z80 data bus D0-D7 (PA0-PA7) as input with pull-up
  PORTA = 0xFF;
  pinMode(RD_, INPUT_PULLUP);                     // Configure RD_ as input with pull-up
  pinMode(WR_, INPUT_PULLUP);                     // Configure WR_ as input with pull-up
  pinMode(AD0, INPUT_PULLUP);
  // Initialize CLK and reset the Z80 CPU
  setCLK(SLOW_CLK);                              // FAST_CLK or SLOW_CLK
  // jednak będzie w stanie WAIT do czasu podania kodu rozkazu (FETCH)
  pinMode(SNMI, OUTPUT);                          // Blokada NMI i INT w CA80
  digitalWrite(SNMI, HIGH);
  delay(1000);
  digitalWrite(RESET_, HIGH);
  while (Serial.available() > 0) Serial.read();   // Flush serial Rx buffer
  // inicjacja klawiatury dotykowej CA80
  pinMode(irqPin, INPUT);
  digitalWrite(irqPin, HIGH);
#if (TOUCH == 1)
  mpr121_setup();
#endif
}

void resetCPU()
{
  digitalWrite(RESET_, LOW);                      // Activate the RESET_ signal
  // Flush serial Rx buffer
  while (Serial.available() > 0)
  {
    Serial.read();
  }

  // Leave the Z80 CPU running
  delay(1);                                       // Just to be sure...
  digitalWrite(WAIT_EN, LOW);
  digitalWrite(WAIT_RES_, LOW);                      //
  digitalWrite(WAIT_RES_, HIGH);                      //
  digitalWrite(RESET_, HIGH);                     // Release Z80 from reset and let it run
  delay(5);                                       // Dla pewnosci zamiast SNMI_ (MCU_CTS)
}

// ------------------------------------------------------------------------------
//  Stale klawiatury
// ------------------------------------------------------------------------------

//const byte PCF_kbd = 0x38;     //Adres PCF8574A 0x38 , dla PCF8574 0x20
// ------------------------------------------------------------------------------
// Kody klawiszy tworzymy wg. wzoru: starsza cyfra nr kolumny, mlodsza ma zero na pozycji
// numeru wiersza
//  wiersz \ kolumna  5 4 3 2 1 0
// -------------------------------
//  3 (0111)          Z C D E F M
//  2 (1011)          Y 8 9 A B G
//  1 (1101)          X 4 5 6 7 .
//  0 (1110)          W 0 1 2 3 =
// ------------------------------------------------------------------------------
const byte noKey = (0xFF);
const byte keyM = (0x07);
const byte keyDot = (0x0D);
const byte keyCR = (0x0E);
const byte keyG = (0x0B);

const byte keyW = (0x5E);
const byte keyX = (0x5D);
const byte keyY = (0x5B);
const byte keyZ = (0x57);

const byte keyCode[] =          //Kody klawiszy 0 - F
{
  (0x4E), // 0
  (0x3E), // 1
  (0x2E), // 2
  (0x1E), // 3
  (0x4D), // 4
  (0x3D), // 5
  (0x2D), // 6
  (0x1D), // 7
  (0x4B), // 8
  (0x3B), // 9
  (0x2B), // A
  (0x1B), // B
  (0x47), // C
  (0x37), // D
  (0x27), // E
  (0x17)  // F
};

// ------------------------------------------------------------------------------
//  Funkcje klawiatury
// ------------------------------------------------------------------------------


void sendKeyCode(byte key)
{
  if ( key > 'Z' )
    key -= 0x20;
  if ( key == 'M' )
  {
    sendKey (keyM);
    return;
  }
  if ( key == 'G' )
  {
    sendKey (keyG);
    return;
  }
  if ( key == '=' )
  {
    sendKey (keyCR);
    return;
  }
  if ( key == '-' )
  {
    sendKey (noKey);
    return;
  }
  if ( key == '.' )
  {
    sendKey (keyDot);
    return;
  }
  if ( key == 'W' )
  {
    sendKey (keyW);
    return;
  }
  if ( key == 'X' )
  {
    sendKey (keyX);
    return;
  }
  if ( key == 'Y' )
  {
    sendKey (keyY);
    return;
  }
  if ( key == 'Z' )
  {
    sendKey (keyZ);
    return;
  }
  if (!(key < '0' || key > 'F'))    // return; //Ignoruj niewlasciwe klawisze
  {
    byte b = (key - 0x30);
    if (b > 0x09)
    {
      b = b - 0x07;
    }
    if (b > 0x0F)
    {
      return;
    }
    sendKey(keyCode[b]);
  }
}

// ------------------------------------------------------------------------------
//  Stale klawiatury
// ------------------------------------------------------------------------------

#define MPR121 0x5A      //Adres MPR121 

// ------------------------------------------------------------------------------
// Kody klawiszy tworzymy wg. wzoru: starsza cyfra nr kolumny, mlodsza ma zero na pozycji
// numeru wiersza
//  wiersz \ kolumna  5 4 3 2 1 0
// -------------------------------
//  3 (0111)          Z C D E F M
//  2 (1011)          X 8 9 A B G
//  1 (1101)          Y 4 5 6 7 .
//  0 (1110)          W 0 1 2 3 =
// ------------------------------------------------------------------------------

// const int irqpin = 2;  // Digital 2

// ------------------------------------------------------------------------------
//  Funkcje klawiatury
// ------------------------------------------------------------------------------

#if (TOUCH == 1)

void czytajKlawiature()
{
  int touchNumber;
  uint16_t touchstatus;
  byte keyCode = 0xFF;     //noKey()
  touchNumber = 0;
  Wire.requestFrom(MPR121, 2);  //read the touch state from the MPR121
  byte LSB = Wire.read();
  byte MSB = Wire.read();
  touchstatus = ((MSB << 8) | LSB); //16bits that make up the touch states
  byte row = 0;
  byte column = 0;
  for (int j = 0; j < 4; j++) // Check how many electrodes were pressed
  {
    if ((touchstatus & (1 << j)))
    {
      touchNumber++;
      row |= 1 << (3 - j);  // Odwrotna kolejnosc elektrod...
    }
  }
  if (touchNumber == 1)
  {
    touchNumber = 0;
    for (int j = 4; j < 10; j++) // Check how many electrodes were pressed
    {
      if ((touchstatus & (1 << j)))
        touchNumber++;
    }
    if (touchNumber == 1)
    {
      for (int j = 4; j < 10; j++) // Check which electrode were pressed
      {
        if ((touchstatus & (1 << j)))
          column = (j - 4);       //
      }
      keyCode = (row ^ 0xF) | ( column << 4 ); // Obliczamy kod klawisza
    }
    else
    {
      keyCode = 0xFF;  //noKey()
    }
  }
  else
  {
    keyCode = 0xFF;     //noKey()
  }
  sendKey(keyCode);
}


void mpr121_setup(void)
{
  set_register(MPR121, ELE_CFG, 0x00);

  // Section A - Controls filtering when data is > baseline.
  set_register(MPR121, MHD_R, 0x01);
  set_register(MPR121, NHD_R, 0x01);
  set_register(MPR121, NCL_R, 0x00);
  set_register(MPR121, FDL_R, 0x00);

  // Section B - Controls filtering when data is < baseline.
  set_register(MPR121, MHD_F, 0x01);
  set_register(MPR121, NHD_F, 0x01);
  set_register(MPR121, NCL_F, 0xFF);
  set_register(MPR121, FDL_F, 0x02);

  // Section C - Sets touch and release thresholds for each electrode
  set_register(MPR121, ELE0_T, TOU_THRESH);
  set_register(MPR121, ELE0_R, REL_THRESH);

  set_register(MPR121, ELE1_T, TOU_THRESH);
  set_register(MPR121, ELE1_R, REL_THRESH);

  set_register(MPR121, ELE2_T, TOU_THRESH);
  set_register(MPR121, ELE2_R, REL_THRESH);

  set_register(MPR121, ELE3_T, TOU_THRESH);
  set_register(MPR121, ELE3_R, REL_THRESH);

  set_register(MPR121, ELE4_T, TOU_THRESH);
  set_register(MPR121, ELE4_R, REL_THRESH);

  set_register(MPR121, ELE5_T, TOU_THRESH);
  set_register(MPR121, ELE5_R, REL_THRESH);

  set_register(MPR121, ELE6_T, TOU_THRESH);
  set_register(MPR121, ELE6_R, REL_THRESH);

  set_register(MPR121, ELE7_T, TOU_THRESH);
  set_register(MPR121, ELE7_R, REL_THRESH);

  set_register(MPR121, ELE8_T, TOU_THRESH);
  set_register(MPR121, ELE8_R, REL_THRESH);

  set_register(MPR121, ELE9_T, TOU_THRESH);
  set_register(MPR121, ELE9_R, REL_THRESH);

  set_register(MPR121, ELE10_T, TOU_THRESH);
  set_register(MPR121, ELE10_R, REL_THRESH);

  set_register(MPR121, ELE11_T, TOU_THRESH);
  set_register(MPR121, ELE11_R, REL_THRESH);

  // Section D
  // Set the Filter Configuration
  // Set ESI2
  set_register(MPR121, FIL_CFG, 0x04);

  // Section E
  // Electrode Configuration
  // Set ELE_CFG to 0x00 to return to standby mode
  set_register(MPR121, ELE_CFG, 0x0A);  // Enables 10 Electrodes


  // Section F
  // Enable Auto Config and auto Reconfig
  /*set_register(MPR121, ATO_CFG0, 0x0B);
    set_register(MPR121, ATO_CFGU, 0xC9);  // USL = (Vdd-0.7)/vdd*256 = 0xC9 @3.3V   set_register(MPR121, ATO_CFGL, 0x82);  // LSL = 0.65*USL = 0x82 @3.3V
    set_register(MPR121, ATO_CFGT, 0xB5);*/  // Target = 0.9*USL = 0xB5 @3.3V

  set_register(MPR121, ELE_CFG, 0x0C);

}

void set_register(int address, unsigned char r, unsigned char v)
{
  Wire.beginTransmission(address);
  Wire.write(r);
  Wire.write(v);
  Wire.endTransmission();
}

#endif

void sendKey (byte k)
{
  Wire.beginTransmission(PCF_KBD);
  Wire.write(k);                    //Wysylamy kod klawisza
  Wire.endTransmission();
}
