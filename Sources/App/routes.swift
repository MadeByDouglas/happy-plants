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
    
    app.post("gardener", ":name", ":plant-name", "light-sensor-data") { req -> LightSensorData in
        let sensorData = try req.content.decode(LightSensorData.self)
        return sensorData
    }

    try app.register(collection: TodoController())
}

struct LightSensorData: Content {
    let value: Int
    let timestamp: Date
}
