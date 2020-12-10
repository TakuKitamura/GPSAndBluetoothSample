import UIKit
import CoreBluetooth
import MapKit

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CLLocationManagerDelegate {
    var myLocationManager: CLLocationManager!
    var centralManager: CBCentralManager!
    var myPeripheral: CBPeripheral!
    
    var location_json_str: String = ""
    var pass_range_check_counter: Int = 0
    var default_value: Double = 0
    var old_value: Double = 0
    var sample_values: [Double] = []
    
    
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
        if peripheral.identifier.uuidString == "5915C5A0-F4F0-8AD6-F78D-0935F1BAAEFE" {
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
//        print(peripheral.services, error)
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
        peripheral.setNotifyValue(true,for: (service.characteristics?.first)!)
        print("Start BLE Service!")
    }

    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print(error)
            return
        }
        if let data = characteristic.value {
            let uint8_data = Array(data)
            

            let data_string = String(bytes: uint8_data, encoding: .utf8)
            print(Array(data))
            let data_value: Double = atof(data_string)
            
//            print(data_value)
        
//            if (sample_values.count < 10) {
//                sample_values.append(data_value)
//                return
//            } else {
//                sample_values.append(data_value)
//                sample_values.removeFirst(1)
//            }
//
//            var sum_values = 0.0
//            for value in sample_values {
//                sum_values += value
//            }
//            let average_value = sum_values / Double(sample_values.count)
        
 
            
            let rate = data_value * 0.05 + old_value * 0.95
            old_value = data_value
            print(rate)
            
            let max_rate = 93.0
            let min_rate = 92.0
            
            if(pass_range_check_counter == 0) {
                if (rate <= max_rate && rate > min_rate) {
                    pass_range_check_counter = 1
                } else {
                    pass_range_check_counter = 0
                }
            } else if (pass_range_check_counter == 1) {
                if (rate < min_rate) {
                    pass_range_check_counter = 2
                    print("Remains Pressed")
                }
            } else if (pass_range_check_counter == 2) {
                if (rate >= min_rate) {
                    print("Released")
                    let url = URL(string: "http://192.168.1.233:8080/api/location")!
                    var request = URLRequest(url: url)
                    request.httpBody = location_json_str.data(using: .utf8)
                    request.httpMethod = "POST"      // Postリクエストを送る(このコードがないとGetリクエストになる)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                        guard let data = data else { return }
                        do {
                            print("API Request Success!")
//                                let object = try JSONSerialization.jsonObject(with: data, options: [])
//                                print(object)
                        } catch let error {
                            print(error)
                        }
                    }
                    task.resume()
                    pass_range_check_counter = 0
                }
            } else {
                print("unexpected value")
            }
        }
        
        return
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        print(locations.first)
        let location = locations.first
        let latitude = location?.coordinate.latitude
        let longitude = location?.coordinate.longitude
        let altitude = location?.altitude
        
        if let unwrap_latitude = latitude, let unwrap_longitude = longitude, let unwrap_altitude = altitude {
            do {
                let formatter = ISO8601DateFormatter()
                let now = formatter.string(from: Date())
                let location_json = try JSONSerialization.data(withJSONObject: ["now": now, "latitude": unwrap_latitude, "longitude": unwrap_longitude, "altitude": unwrap_altitude], options: [])
                location_json_str = String(bytes: location_json, encoding: .utf8)!
//                print(location_json_str)
            } catch let error {
                print(error)
            }
//            print(unwrap_latitude, unwrap_longitude, unwrap_altitude)
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        myLocationManager = CLLocationManager()
        myLocationManager.requestAlwaysAuthorization()
        myLocationManager.delegate = self
        myLocationManager.desiredAccuracy = kCLLocationAccuracyBest
//        myLocationManager.distanceFilter = 100
        myLocationManager.startUpdatingLocation()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}
