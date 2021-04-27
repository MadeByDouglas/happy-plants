import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }
    
    app.get("gardener", ":name") { req -> String in
        let name = req.parameters.get("name")!
        return "Hello, \(name)!"
    }
    
    //arduino update light data
    app.post("gardener", ":name", ":plant-name", "light") { req -> String in
        let name = req.parameters.get("name")!
        let plantName = req.parameters.get("plant-name")!
        let arduinoData = try req.content.decode(ArduinoSensorData.self)
        let sensorData = Light(value: arduinoData.value, timestamp: Date())
        
        guard var existingPlant = data[name]?[plantName] else {
            return "No plant with the name \(plantName) owned by \(name) exists"
        }
        
        // if light changes drastically someone is probably moving it, or somehow casting a shadow
        if abs(sensorData.value - existingPlant.lightData.value) > 150 {
            existingPlant.lastInteraction = sensorData.timestamp
        }
        
        // update data
        existingPlant.lightData = sensorData
        
        // set mood
        if sensorData.value < 50 {
            existingPlant.mood = .scared
        } else if sensorData.value > 600 {
            existingPlant.mood = .hot
        }
        
        //determine date difference
        
        //ensure previous date
        let interval = Date() - existingPlant.lastInteraction
        if interval > 100 {
            existingPlant.mood = .sad
        } else if interval < 10 {
            existingPlant.mood = .happy
        }
        
        print(data[name]?[plantName] as Any)
        
        //just in case make sure its saved back to dictionary
        data[name]?[plantName] = existingPlant
        
        return "\(name)'s lovely plant \(plantName) updated light value: \(sensorData.value) at \(sensorData.timestamp)"
    }
    
    //arduino update soil water data
    app.post("gardener", ":name", ":plant-name", "water") { req -> String in
        let name = req.parameters.get("name")!
        let plantName = req.parameters.get("plant-name")!
        let arduinoData = try req.content.decode(ArduinoSensorData.self)
        let sensorData = Water(value: arduinoData.value, timestamp: Date())

        
        guard var existingPlant = data[name]?[plantName] else {
            return "No plant with the name \(plantName) owned by \(name) exists"
        }
        
        // if large positive delta is found user probably watered the plant
        if sensorData.value - existingPlant.waterData.value > 200 {
            existingPlant.lastWatered = sensorData.timestamp
            // also is an interaction
            existingPlant.lastInteraction = sensorData.timestamp
        }

        // update data
        existingPlant.waterData = sensorData
        
        // set mood
        if sensorData.value < 400 {
            existingPlant.mood = .thirsty
        } else if sensorData.value < 900 {
            existingPlant.mood = .chill
        } else if sensorData.value > 900 {
            existingPlant.mood = .drunk
        }
        
        print(data[name]?[plantName] as Any)
        
        //just in case make sure its saved back to dictionary
        data[name]?[plantName] = existingPlant

        return "\(name)'s lovely plant \(plantName) updated water value: \(sensorData.value) at \(sensorData.timestamp)"
    }
    
    //app creates user and plant
    app.post("gardener", ":name", "add-plant") { req -> String in
        let name = req.parameters.get("name")!
        let newPlant = try req.content.decode(Plant.self)
        
        
        data[name]?[newPlant.name] = newPlant
        
        return "New plant named \(newPlant.name) created for \(name)"

    }
    
    // get all plants
    app.get("plants") { req -> [Plant] in
        
        var allPlants: [Plant] = []
        for key in data.keys {
            if let plants = data[key]?.values.map({$0}) {
                allPlants.append(contentsOf: plants)
            }
        }
        return allPlants
    }
    
    // get my plants
    app.get("gardener", ":name", "plants") { req -> [Plant] in
        let name = req.parameters.get("name")!
        guard let myPlants = data[name]?.values.map({$0}) else {
            return []
        }
        return myPlants
    }

    try app.register(collection: TodoController())
}


// TEMP DATABASE
// because postgres is hard

var data: [String:[String:Plant]] = [:]

// MODELS
// for simplicity models and everything here

struct Gardener: Codable {
    var name: String
    var bio: String
}

struct Plant: Codable, Identifiable, Content {
    var id: UUID
    var name: String
    var owner: Gardener
    var mood: Mood
    var lightData: Light
    var waterData: Water
    var lastInteraction: Date //when there is large delta in either light or water this date updates with sensor data timestamp
    var lastWatered: Date //when there is large positive delta in water triggers this timestamp
    var imageName: String
}

//arduino can't get date, just sends basic int
struct ArduinoSensorData: Codable {
    var value: Int
}

struct Light: Codable {
    var value: Int
    var timestamp: Date
}

struct Water: Codable {
    var value: Int
    var timestamp: Date
}


enum Mood: String, Codable {
    case happy = "🥳" // recent interaction
    case sad = "🙁" // no interaction for some time
    case chill = "😎" // appropriate light and water
    case scared = "😱" // very low light sensor
    case thirsty = "😥" // low water sensor
    case hot = "🥵" // very high light sensor
    case drunk = "🥴" // very hight water sensor
}

// Soil Calibration from testing different soil conditions
// well watered > 800
// some water > 700
// dry < 400
// air < 100


// Light Calibration from testing different light conditions
// very bright > 600
// indoor 80 - 200
// dark < 50



// date stuff

extension Date {

    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }

}
