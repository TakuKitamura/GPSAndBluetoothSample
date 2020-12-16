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

// Service, Characteristic UUID: 適宜変更する
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// HTTPサーバのポート
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
  // 値を受け取った場合
  void onWrite(BLECharacteristic *pCharacteristic)
  {
    std::string value = pCharacteristic->getValue();

    if (value.length() > 0)
    {
      writeValue = value;
      Serial.print("Receive value: ");
      for (int i = 0; i < value.length(); i++)
        Serial.print(value[i]);
      Serial.println();
    }
  }

  // 値を読み込んだ場合
  void onRead(BLECharacteristic *pCharacteristic)
  {
    pCharacteristic->setValue(writeValue);
  }
};

// 初期化
void setup()
{
  Serial.begin(115200);

  // BLEデバイス名
  BLEDevice::init("BLE");

  // Bluetooth設定
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_NOTIFY |
          BLECharacteristic::PROPERTY_INDICATE);

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  pServer->getAdvertising()->start();

  //アクセスポイントを起動する
  // アクセスポイント名, パスワード(無しの場合, 空文字列)
  WiFi.softAP("ESP32ap", "");

  if (!MDNS.begin("esp32"))
  {
    while (1)
    {
      delay(1000);
    }
  }

  server.begin();

  // HTTPサーバ
  MDNS.addService("http", "tcp", 80);
}

// 継続処理
void loop()
{
  WiFiClient client = server.available();
  if (!client)
  {
    return;
  }

  if (client)
  {
    while (client.connected())
    {
      if (client.available())
      {
        // 以下, 接続クライアントからHTTP接続が来た場合の処理
        String req = client.readStringUntil('\r');

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
          s = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n";

          // クライアントから受け取っているHTMLをレスポンスとして返す
          s += writeValue.c_str();
          s += "\r\n\r\n";
          Serial.println("Sending 200");
        }
        else
        {

          s = "HTTP/1.1 404 Not Found\r\n\r\n";
          Serial.println("Sending 404");
        }

        client.print(s);
        client.flush();
        client.stop();
      }
    }
  }
}
