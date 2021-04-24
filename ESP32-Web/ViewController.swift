import UIKit
import CoreBluetooth
import MapKit

// TODO: UUID関係は適宜書き換える

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITextFieldDelegate, UITextViewDelegate {
    var centralManager: CBCentralManager!
    var myPeripheral: CBPeripheral!
    var cbcChar: CBCharacteristic!
    var myTextView: UITextView!
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            print("BLE powered on")
            // Turned on
            let _: [CBUUID] = [CBUUID(string: "5915C5A0-F4F0-8AD6-F78D-0935F1BAAEFE")]
            central.scanForPeripherals(withServices: nil)
        }
        else {
            print("Something wrong with BLE")
            // Not on, but can have different issues
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral.name, peripheral.identifier)
        if peripheral.identifier.uuidString == "BAF91016-3250-7F30-4EC8-D1A4F08D7B58" {
            self.centralManager.stopScan()
            
            self.myPeripheral = peripheral
            self.myPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let service: [CBUUID] = [CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")]
        self.myPeripheral.discoverServices(service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let peripheralServices = peripheral.services {
            for service in peripheralServices where service.uuid == CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
                // キャラクタリスティック探索開始
                let characteristicUUIDArray: [CBUUID] = [CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")]
                peripheral.discoverCharacteristics(characteristicUUIDArray, for: service)
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print(error)
            return
        }
        
        cbcChar = (service.characteristics?.first)!
        print("Start BLE Service!")
    }

    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard error == nil else {
            print(error)
            return
        }

        // esp32からデータを受け取る場合の処理(現在は利用していない)
        if let data = characteristic.value {
            let uint8_data = Array(data)
            
            let data_string = String(bytes: uint8_data, encoding: .utf8)
            print(Array(data))
            let data_value: Double = atof(data_string)
            
        }
        
        return
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let data = textField.text!.data(using: String.Encoding.utf8, allowLossyConversion:true)
        self.myPeripheral.writeValue(data!, for: cbcChar, type: .withResponse)
        return true
    }
    
    @objc func commitButtonTapped(sender: Any) { // buttonの色を変化させるメソッド
        let data = myTextView.text!.data(using: String.Encoding.utf8, allowLossyConversion:true)

        // esp32にデータを送信
        self.myPeripheral.writeValue(data!, for: cbcChar, type: .withResponse)
        self.view.endEditing(true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // HTML書き込み画面
        myTextView = UITextView(frame: CGRect(x:0, y:50, width:self.view.frame.width, height:self.view.frame.height-50))
        myTextView.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        myTextView.text = "<h1>Hello World!</h1>"
        myTextView.font = UIFont.systemFont(ofSize: CGFloat(20))
        myTextView.textColor = UIColor.black
        myTextView.textAlignment = NSTextAlignment.left
        myTextView.dataDetectorTypes = UIDataDetectorTypes.all //日付や数字の色を変更する
        myTextView.isEditable = true;
        myTextView.delegate = self;
        
        // TextViewをViewに追加する.
        self.view.addSubview(myTextView)
        
        
        // ツールバー生成
         let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
         // スタイルを設定
         toolBar.barStyle = UIBarStyle.default
         // 画面幅に合わせてサイズを変更
         toolBar.sizeToFit()
         // 閉じるボタンを右に配置するためのスペース?
         let spacer = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
         // 閉じるボタン
         let commitButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(commitButtonTapped))
         // スペース、閉じるボタンを右側に配置
         toolBar.items = [spacer, commitButton]
         // textViewのキーボードにツールバーを設定
        myTextView.inputAccessoryView = toolBar
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}
