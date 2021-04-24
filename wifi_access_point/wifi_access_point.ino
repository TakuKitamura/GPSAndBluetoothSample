#include <WiFi.h>
#include <ESPmDNS.h>
#include <WiFiClient.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
std::string writeValue = "<h1>No Data...</h1>";

#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

/* TCP server at port 80 will respond to HTTP requests */
WiFiServer server(80);

class MyServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *pServer)
  {
    deviceConnected = true;
  };

  void onDisconnect(BLEServer *pServer)
  {
    deviceConnected = false;
  }
};

class MyCallbacks : public BLECharacteristicCallbacks
{
  void onWrite(BLECharacteristic *pCharacteristic)
  {
    std::string value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      writeValue = value;
      Serial.println("*********");
      Serial.print("New value: ");
      for (int i = 0; i < value.length(); i++)
        Serial.print(value[i]);
      Serial.println();
      Serial.println("*********");
    }
  }
  void onRead(BLECharacteristic *pCharacteristic)
  {
    pCharacteristic->setValue(writeValue);
  }
};

void setup()
{
  Serial.begin(115200);

  BLEDevice::init("BLE");

  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_NOTIFY |
          BLECharacteristic::PROPERTY_INDICATE);

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  pServer->getAdvertising()->start();

  //アクセスポイントを起動する
  WiFi.softAP("ESP32ap", "");

  if (!MDNS.begin("esp32"))
  {
    while (1)
    {
      delay(1000);
    }
  }

  server.begin();

  /* Add HTTP service to MDNS-SD */
  MDNS.addService("http", "tcp", 80);
}

void loop()
{
  WiFiClient client = server.available();
  if (!client)
  {
    return;
  }

  if (client)
  {
    /* check client is connected */
    while (client.connected())
    {
      /* client send request? */
      if (client.available())
      {
        /* request end with '\r' -> this is HTTP protocol format */
        String req = client.readStringUntil('\r');
        /* now we parse the request to see which page the client want */
        int addr_start = req.indexOf(' ');
        int addr_end = req.indexOf(' ', addr_start + 1);
        if (addr_start == -1 || addr_end == -1)
        {
          return;
        }
        req = req.substring(addr_start + 1, addr_end);

        String s = "";
        if (req == "/")
        {
          //                  IPAddress ip = client.localIP();  // サーバ側のIPアドレス
          //                  IPAddress ip = client.remoteIP();   // クライアント側のIPアドレス
          //                  String ipStr = String(ip[0]) + '.' + String(ip[1]) + '.' + String(ip[2]) + '.' + String(ip[3]);
          s = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n";
          s += "<meta charset=\"UTF-8\" http-equiv=\"refresh\" content=\"5\">";
          s += writeValue.c_str();
          s += "\r\n\r\n";
          Serial.println("Sending 200");
        }
        else
        {
          /* if we can not find the page that client request then we return 404 File not found */
          s = "HTTP/1.1 404 Not Found\r\n\r\n";
          Serial.println("Sending 404");
        }
        /* send response back to client and then close connect since HTTP do not keep connection*/
        client.print(s);
        client.flush();
        client.stop();
      }
    }
  }
}