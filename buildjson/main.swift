//
//  main.swift
//  buildjson
//
//  Created by Fred Hewett on 3/16/15.
//  Copyright (c) 2015 Frederick Hewett. All rights reserved.
//

import Foundation
import CoreLocation

//var basePath = "/Users/fred/Documents/xc/buildjson/GTFS/vta-2015/";var allowConnections: Bool = true
var basePath = "/Users/fred/Documents/xc/buildjson/GTFS/ferries/";var allowConnections: Bool = false

struct Agency {
    // agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang
    let id: String
    let name: String
    let url: String
    let timezone: String
    let phone: String
    let lang: String
}

struct Stop {
    //stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon
    let id: String
    let code: String
    let name: String
    let desc: String
    let lat: Double
    let lng: Double
}

struct Waypoint {
    let id: String
    let routeId: String
    let name: String
}

struct Trip {
    // route_id,service_id,trip_id,trip_headsign,shape_id
    let routeId: String
    let serviceId: String
    let tripId: String
    let tripHeadsign: String
    let shapeId: String
}

struct Route {
    // route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_url,route_color,route_text_color
    let routeId: String
    let agencyId: String
    let shortName: String
    let longName: String
    let description: String
    let type: String
    let url: String
    let color: String
    let textColor: String
}

struct StopTime {
    // trip_id,arrival_time,departure_time,stop_id,stop_sequence
    let tripId: String
    let arrivalTime: String
    let departureTime: String
    let stopId: String
    let stopSequence: Int
}

struct Shape {
    // shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence
    let shapeId: String
    let lat: Double
    let lng: Double
    let seq: Int
}

struct Calendar {
    // service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date
    let serviceId: String
    let daysMonToSun: [Bool]
    let startDate: String
    let endDate: String
}

struct CalendarDate {
    // service_id,date,exception_type
    let serviceId: String
    let date: String
    let exceptionType: Int
}

struct GTFS {
    let agencies: [Agency]
    let stops: [Stop]
    let stopTimes: [StopTime]
    let calendars: [Calendar]
    let calendarDates: [CalendarDate]
    let trips: [Trip]
    let shapes: [Shape]
    let routes: [Route]
    let waypoints: [Waypoint]
}


struct Connection {
    let routeId: String
    let headSign: String
    let tripId: String
    let time: TimeOfDay
    let shortName: String
}

struct TimeOfDay : Comparable, Equatable {
    let hour: Int!
    let minute: Int!
    
    init(fromString string: String) {
        let array = string.characters.split {$0 == ":"}.map { String($0) }
        
        self.hour = (array[0] as NSString).integerValue
        self.minute = (array[1] as NSString).integerValue
    }
    
}

func <(lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
    if lhs.hour < rhs.hour {
        return true
    }
    if lhs.hour > rhs.hour {
        return false
    }
    if lhs.minute < rhs.minute {
        return true
    }
    
    return false
}
func ==(lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
    if lhs.hour != rhs.hour {
        return false
    }
    if lhs.minute != rhs.minute {
        return false
    }
    return true
}


func trim(_ string: String) -> String {
    let components = string.components(
        separatedBy: CharacterSet.whitespacesAndNewlines).filter({!$0.characters.isEmpty}
    )
    return components.joined(separator: " ")
}

func isBlank(_ line: String) -> Bool {
    return (line.characters.count == 0) || ((line.characters.count == 1) &&
        (line.substring(to: line.characters.index(line.startIndex, offsetBy: 1)) == "\r"))
}

func isCommentLine(_ line: String) -> Bool {
    return (line.characters.count >= 2) && (line.substring(to: line.characters.index(line.startIndex, offsetBy: 2)) == "//")
}

func decomposeCsv(_ line: String) -> [String] {
    var parts = line.components(separatedBy: ",")
    
    var result = [String]()

    var combine = false
    var build: String = ""
    
    for i in (0 ..< parts.count) {
        var s = trim(parts[i])
        if s.range(of: "\"") != nil {
            
            if s.substring(to: s.characters.index(after: s.startIndex)) == "\"" && s.substring(from: s.characters.index(before: s.endIndex)) == "\"" {
                s = s.substring(with: (s.characters.index(after: s.startIndex) ..< s.characters.index(before: s.endIndex)))
                result.append(s)
            }
            else if combine {
                combine = false
                s = s.substring(to: s.characters.index(before: s.endIndex))
                build += "," + s
                result.append(build)
            }
            else {
                build = s.substring(from: s.characters.index(s.startIndex, offsetBy: 1))
                combine = true
            }
        }
        else if combine {
            build += "," + parts[i]
        }
        else {
            result.append(parts[i])
        }
        
    }

    return result
}

func formatTimeOfDay(_ tod: TimeOfDay) -> String {
    let minutes = tod.minute < 10 ? "0" + String(tod.minute) : String(tod.minute)
    let hour = tod.hour < 10 ? " " + String(tod.hour) : String(tod.hour)
    
    return hour + ":" + minutes
}


func getFieldMap(_ fieldList: String) -> [String: Int] {
    var result = [String: Int]()
    let parts = fieldList.components(separatedBy: ",")
  
    for i in 0 ..< parts.count {
        result[trim(parts[i])] = i
    }
    
    return result
}

func getField(_ field: String, map: [String: Int], list: [String]) -> String {
    return map[field] == nil ? "" : trim(list[map[field]!])

}

func parseAgencies() -> [Agency] {
    // agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang
    let path = basePath + "agency.txt"
    
    var agencies = [Agency]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        var fieldMap: [String: Int]!
        
        while let line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }
            let parts = decomposeCsv(line)
            
            let id = getField("agency_id", map: fieldMap, list: parts)
            let name = getField("agency_name", map: fieldMap, list: parts)
            let url = getField("agency_url", map: fieldMap, list: parts)
            let timezone = getField("agency_timezone", map: fieldMap, list: parts)
            let phone = getField("agency_phone", map: fieldMap, list: parts)
            let lang = getField("agency_lang", map: fieldMap, list: parts)
            
            let agency = Agency(id: id, name: name, url: url, timezone: timezone, phone: phone, lang: lang)
            agencies.append(agency)
            
        }
        reader.close();
    }
    
    return agencies
}

func parseStops() -> [Stop] {
    //stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon
    let path = basePath + "stops.txt"
    
    var stops = [Stop]()
    if let reader = StreamReader(path: path) {

        var isFirst = true
        var fieldMap: [String: Int]!
        
        while let line = reader.nextLine() {
            if isBlank(line) || isCommentLine(line){
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }

            let parts = decomposeCsv(line)

            let id = getField("stop_id", map: fieldMap, list: parts)
            let code = getField("stop_code", map: fieldMap, list: parts)
            let name = getField("stop_name", map: fieldMap, list: parts)
            let desc = getField("stop_desc", map: fieldMap, list: parts)
            let lat = (getField("stop_lat", map: fieldMap, list: parts) as NSString).doubleValue
            let lng = (getField("stop_lon", map: fieldMap, list: parts) as NSString).doubleValue
            
            let stop = Stop(id: id, code: code, name: name, desc: desc, lat: lat, lng: lng)
            stops.append(stop)

        }
        reader.close();
    }
    
    return stops
}


func parseWaypoints() -> [Waypoint] {
//    waypoint_id,route_id,waypoint_name

    let path = basePath + "waypoints.txt"
    
    var wps = [Waypoint]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        var fieldMap: [String: Int]!
        
        while let line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }
            let parts = decomposeCsv(line)
            
            let id = getField("waypoint_id", map: fieldMap, list: parts)
            let routeId = getField("route_id", map: fieldMap, list: parts)
            let name = getField("waypoint_name", map: fieldMap, list: parts)
            
            let wp = Waypoint(id: id, routeId: routeId, name: name)
            wps.append(wp)
            
        }
        reader.close();
    }
    
    return wps
}


func parseTrips() -> [Trip] {
    // route_id,service_id,trip_id,trip_headsign,shape_id
    
    let path = basePath + "trips.txt"
    
    var trips = [Trip]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        var fieldMap : [String: Int]!
        while let line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }
            let parts = decomposeCsv(line)

            let routeId = getField("route_id", map: fieldMap, list: parts)
            let serviceId = getField("service_id", map: fieldMap, list: parts)
            let tripId = getField("trip_id", map: fieldMap, list: parts)
            let tripHeadsign = getField("trip_headsign", map: fieldMap, list: parts)
            let shapeId = getField("shape_id", map: fieldMap, list: parts)
            
            let trip = Trip(routeId: routeId, serviceId: serviceId, tripId: tripId, tripHeadsign: tripHeadsign, shapeId: shapeId)
            trips.append(trip)
        }
    }
    
    return trips
}

func parseRoutes() -> [Route] {
    let path = basePath + "routes.txt"
    
    var routes = [Route]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        
        var fieldMap: [String: Int]!
        while var line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }
            
            line = trim(line)
            if line.isEmpty {
                continue
            }
            
            let parts = decomposeCsv(line);

            let routeId = getField("route_id", map: fieldMap, list: parts)
            let agencyId = getField("agency_id", map: fieldMap, list: parts)
            let shortName = getField("route_short_name", map: fieldMap, list: parts)
            let longName = getField("route_long_name", map: fieldMap, list: parts)
            let description = getField("route_desc", map: fieldMap, list: parts)
            let type = getField("route_type", map: fieldMap, list: parts)
            let url = getField("route_url", map: fieldMap, list: parts)
            let color = getField("route_color", map: fieldMap, list: parts)
            let textColor = getField("route_text_color", map: fieldMap, list: parts)
            
            let route = Route(routeId: routeId, agencyId: agencyId, shortName: shortName, longName: longName,
                description: description, type: type, url: url, color: color, textColor: textColor)
            routes.append(route)
        }
    }
    
    return routes
}

func parseStopTimes() -> [StopTime] {
    // trip_id,arrival_time,departure_time,stop_id,stop_sequence
    let path = basePath + "stop_times.txt"
    
    var stopTimes = [StopTime]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        var fieldMap: [String: Int]!
        while let line = reader.nextLine() {
            if isBlank(line) || isCommentLine(line) {
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }
            let parts = decomposeCsv(line)
            
            let tripId = getField("trip_id", map: fieldMap, list: parts)
            let arrivalTime = trim(getField("arrival_time", map: fieldMap, list: parts)).substring(to: parts[1].characters.index(parts[1].startIndex, offsetBy: 5))
            let departureTime = trim(getField("departure_time", map: fieldMap, list: parts)).substring(to: parts[1].characters.index(parts[1].startIndex, offsetBy: 5))
            let stopId = getField("stop_id", map: fieldMap, list: parts)
            let stopSequence = (getField("stop_sequence", map: fieldMap, list: parts) as NSString).integerValue
            
            let stopTime = StopTime(tripId: tripId, arrivalTime: arrivalTime, departureTime: departureTime, stopId: stopId, stopSequence: stopSequence)
            
            stopTimes.append(stopTime)
        }
    }
    
    return stopTimes
}

func parseShapes() -> [Shape] {
    // shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence
    let path = basePath + "shapes.txt"
    
    var shapes = [Shape]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        var fieldMap: [String: Int]!
        while let line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                fieldMap = getFieldMap(line)
                isFirst = false
                continue
            }
            let parts = decomposeCsv(line)
            let shapeId = getField("shape_id", map: fieldMap, list: parts)
            let slat = trim(getField("shape_pt_lat", map: fieldMap, list: parts))
            let lat = (slat as NSString).doubleValue
            let slng = trim(getField("shape_pt_lon", map: fieldMap, list: parts))
            let lng = (slng as NSString).doubleValue
            let sseq = trim(getField("shape_pt_sequence", map: fieldMap, list: parts))
            let seq = (sseq as NSString).integerValue
            
            let shape = Shape(shapeId: shapeId, lat: lat, lng: lng, seq: seq)
            
            shapes.append(shape)
        }
    }
    
    return shapes
}

func parseDate(_ yyyymmdd: String) -> String {
    var yyyymmdd = yyyymmdd
    yyyymmdd = trim(yyyymmdd)
    
    var start = yyyymmdd.startIndex
    var end = yyyymmdd.index(start, offsetBy: 4)
    
    let year = yyyymmdd.substring(with: (start ..< end))
    
    start = end
    end = yyyymmdd.index(start, offsetBy: 2)
    let month = yyyymmdd.substring(with: (start ..< end))
    
    start = end
    end = yyyymmdd.index(start, offsetBy: 2)
    let day = yyyymmdd.substring(with: (start ..< end))
    
    let dateString = "\(year)-\(month)-\(day)"
    return dateString
}


func parseCalendars() -> [Calendar] {
    let path = basePath + "calendar.txt"
    
    var calendars = [Calendar]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        
        while let line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                isFirst = false
                continue
            }
            let parts = decomposeCsv(line)
            
            let serviceId = parts[0]
            
            var days = [Bool](repeating: false, count: 7)
            for i in (1 ... 7) {
                if parts[i] == "1" {
                    days[i-1] = true
                }
            }
            
            let startDate = parseDate(parts[8])
            let endDate = parseDate(parts[9])
            
            let calendar = Calendar(serviceId: serviceId, daysMonToSun: days, startDate: startDate, endDate: endDate)
            calendars.append(calendar)
        }
    }
    
    return calendars
}

func parseCalendarDates() -> [CalendarDate] {
    // service_id,date,exception_type
    
    let path = basePath + "calendar_dates.txt"
    
    var calendarDates = [CalendarDate]()
    if let reader = StreamReader(path: path) {
        
        var isFirst = true
        var fieldMap: [String: Int]!
        while let line = reader.nextLine() {
            if isBlank(line) {
                continue
            }
            if isFirst {
                isFirst = false
                fieldMap = getFieldMap(line)
                continue
            }
            let parts = decomposeCsv(line)
            
            let serviceId = getField("service_id", map: fieldMap, list: parts)
            let date = parseDate(getField("date", map: fieldMap, list: parts))
            let sexc = trim(getField("exception_type", map: fieldMap, list: parts))
            let exceptionType = (sexc as NSString).integerValue

            let calendarDate = CalendarDate(serviceId: serviceId, date: date, exceptionType: exceptionType)
            calendarDates.append(calendarDate)
        }
    }
    
    return calendarDates
}

func getTripsForRoute(_ routeId: String, gtfs: GTFS) -> [Trip] {
    var trips = [Trip]()
    for trip in gtfs.trips {
        if trip.routeId == routeId {
            trips.append(trip)
        }
    }
    return trips
}

func getStopTimesForTrip(_ tripId: String, gtfs: GTFS) -> [StopTime] {
    var stopTimes = [StopTime]()
    
    for st in gtfs.stopTimes {
        if st.tripId == tripId {
            stopTimes.append(st)
        }
    }
    
    return stopTimes
}


func getUniqueDestinationsFromTrips(_ trips: [Trip]) -> [String] {
    var uniqueDestinations = [String]()
    for trip in trips {
        if !trip.tripHeadsign.isEmpty && !uniqueDestinations.contains(trip.tripHeadsign) {
            uniqueDestinations.append(trip.tripHeadsign)
        }
    }
    return uniqueDestinations
}

func indent(_ level: Int = 1) -> String {
    let indent = "\t"
    var result = ""
    for _ in (0 ..< level) {
        result += indent
    }
    return result
}


func getConnectionsForTrip(_ trip: Trip, gtfs: GTFS) -> [Connection] {
    var result = [Connection]()
    if !allowConnections {
        return result
    }
    let stopTimes = getStopTimesForTrip(trip.tripId, gtfs: gtfs)
    if stopTimes.count == 0 {
        return result
    }
    let lastStop = stopTimes.last!
    // algo: find all trips that have last stop as first stop
    // identify subset with start time within one hour after arrival at terminal
    // for each qualifying, determine the route and destination (from Trip)
    // for each route, return the earliest trip

    
    typealias IdAndTime = (id: String, tod: TimeOfDay)
    
    var idsOfQualifyingTrips = [IdAndTime]()
    for st: StopTime in gtfs.stopTimes {
        if ((st.stopSequence == 1) && (st.stopId == lastStop.stopId) && (st.tripId != trip.tripId) ) {
            
            let arrivalTime = TimeOfDay(fromString: lastStop.arrivalTime)
            let departureTime = TimeOfDay(fromString: st.arrivalTime)
            let arrivalMinutes = arrivalTime.hour * 60 + arrivalTime.minute
            let departureMinutes = departureTime.hour * 60 + departureTime.minute
            if (departureMinutes > arrivalMinutes) && ((departureMinutes - arrivalMinutes) <= 60) {
                idsOfQualifyingTrips.append((id: st.tripId, tod: departureTime))
            }
        }
    }
    
    typealias TripAndTime = (trip: Trip, time: TimeOfDay)
    var routeDico = [String: TripAndTime]()  // routeId: Trip,Time
    for qualifier in idsOfQualifyingTrips {
        
        var connecting: Trip?
        for t in gtfs.trips {
            if t.tripId == qualifier.id {
                connecting = t
                break
            }
        }
        if connecting != nil && connecting!.routeId != trip.routeId {
            if routeDico[connecting!.routeId] == nil {
                routeDico[connecting!.routeId] = (trip: connecting!, time: qualifier.tod)
            }
            else {
                let currentEntryTime = routeDico[connecting!.routeId]!.time
                let qualMinutes = qualifier.tod.hour * 60 + qualifier.tod.minute
                let currMinutes = currentEntryTime.hour * 60 + currentEntryTime.minute
                
                if qualMinutes < currMinutes {
                    routeDico[connecting!.routeId] = (trip: connecting!, time: qualifier.tod)
                }
            }
        }
    }

    for routeId in routeDico.keys {
        var shortName: String = ""
        for r in gtfs.routes {
            if r.routeId == routeId {
                shortName = r.shortName
                break
            }
        }
        
        let entry = routeDico[routeId]!
        let connection = Connection(routeId: routeId, headSign: entry.trip.tripHeadsign, tripId: entry.trip.tripId, time: entry.time, shortName: shortName)
        result.append(connection)
    }
    
    return result
}

func generateJsonForTrip(_ trip: Trip, isLast: Bool, gtfs: GTFS) {
    let level = 5

    print("\(indent(level)){")
    print("\(indent(level+1))\"tripId\": \"\(trip.tripId)\",")
    print("\(indent(level+1))\"calId\": \"\(trip.serviceId)\",")
    print("\(indent(level+1))\"stops\": [")
    
    let stopTimes = getStopTimesForTrip(trip.tripId, gtfs: gtfs)
    var first = stopTimes.count > 1
    for st in stopTimes {
    
        print("\(indent(level+2)){ \"id\": \"\(st.stopId)\", \"time\": \"\(st.arrivalTime)\", \"seq\": \(st.stopSequence) }", terminator: "")
        if first || (st.stopId != stopTimes.last!.stopId) {
            print(",", terminator: "")
        }
        first = false
        print("")
    }
    
    print("\(indent(level+1))],")
    
    print("\(indent(level+1))\"connections\": [")

    let connections = getConnectionsForTrip(trip, gtfs: gtfs)
    if connections.count > 0 {
        let lastRoute = connections.last!.routeId
        for c in connections {
            print("\(indent(level+2)){\"routeId\": \"\(c.routeId)\", \"headsign\": \"\(c.headSign)\", \"tripId\": \"\(c.tripId)\", \"shortName\": \"\(c.shortName)\", \"time\": \"\(formatTimeOfDay(c.time))\"}", terminator: "")
            if c.routeId != lastRoute {
                print(",", terminator: "")
            }
            print("")
        }
    }
    
    print("\(indent(level+1))]")
    
    print("\(indent(level))}", terminator: "")
    if (!isLast) {
        print(",")
    }
    print("")
}

func getTripsToDestination(destination: String, fromTrips: [Trip]) -> [Trip] {
    var result = [Trip]()
    for t in fromTrips {
        if t.tripHeadsign == destination {
            result.append(t)
        }
    }
    
    return result
}

func getCoordinatesForShape(_ shapeId: String, gtfs: GTFS) -> [CLLocationCoordinate2D] {
    var coords = [CLLocationCoordinate2D]()
    for shape in gtfs.shapes {
        if shape.shapeId == shapeId {
            let coord = CLLocationCoordinate2D(latitude: shape.lat, longitude: shape.lng)
            coords.append(coord)
        }
    }
    
    return coords
}

func getWayPointForRoute(_ routeId: String, gtfs: GTFS) -> String {
    for wp in gtfs.waypoints {
        if wp.routeId == routeId {
            return wp.name
        }
    }
    
    return ""
}

func getTripStartTime(_ trip: Trip) -> TimeOfDay? {
    let stopTimes = getStopTimesForTrip(trip.tripId, gtfs: gtfs)
    if stopTimes.count > 0 {
        return TimeOfDay(fromString: stopTimes[0].arrivalTime)
    }
    return nil
}

func sortTripsByStartTime(_ trips: inout [Trip]) {
    trips.sort { (t1, t2) in
        let time1 = getTripStartTime(t1)
        let time2 = getTripStartTime(t2)
        if (time1 == nil) || (time2 == nil) {
            return false
        }
        
        return time1! < time2!
    }
}

func generateJsonForRoute(_ route: Route, isLast: Bool, gtfs: GTFS) {
    let level = 3

    let trips = getTripsForRoute(route.routeId, gtfs: gtfs)
    if trips.isEmpty {
        return
    }
    
    let wp = getWayPointForRoute(route.routeId, gtfs: gtfs)
    
    print("\(indent()){")
    print("\(indent(level))\"id\": \"\(route.routeId)\",")
    print("\(indent(level))\"agency\": \"\(route.agencyId)\",")
    print("\(indent(level))\"shortName\": \"\(route.shortName)\",")
    print("\(indent(level))\"longName\": \"\(route.longName)\",")
    print("\(indent(level))\"colorCode\": \"\(route.color)\",")
    print("\(indent(level))\"waypoint\": \"\(wp)\",")
    print("\(indent(level))\"vectors\": [")
    
    // a vector is an array of Trip that have the same routeId and Heading
    var destinations = getUniqueDestinationsFromTrips(trips)
    if destinations.isEmpty {
        destinations.append("Loop")
    }
    
    for dest in destinations {
        var tripsToDest: [Trip]!
        if destinations[0] != "Loop" {
            tripsToDest = getTripsToDestination(destination: dest, fromTrips: trips)
        }
        else {
            tripsToDest = trips
        }
        
        sortTripsByStartTime(&tripsToDest!)
        
        print("\(indent(level)){")
        print("\(indent(level+1))\"destination\": \"\(dest)\",")
        print("\(indent(level+1))\"trips\": [")
        for trip in tripsToDest {
            generateJsonForTrip(trip, isLast: trip.tripId == tripsToDest.last!.tripId, gtfs: gtfs)
        }
        print("\(indent(level+1))],")

        if (tripsToDest.count > 0) {
            let shapeId = trim(tripsToDest[0].shapeId)
            let coords = getCoordinatesForShape(shapeId, gtfs: gtfs)
            let poly = Polyline(coordinates: coords, levels: nil)
            let polyString = poly.encodedPolyline.replacingOccurrences(of: "\\", with: "\\\\", options: NSString.CompareOptions.literal, range: nil)
            print("\(indent(level+1))\"polyline\": \"\(polyString)\"")
        }
        
        print("\(indent(level))}", terminator: "")
        if dest != destinations.last {
            print(",", terminator: "")
        }
        print("")
    }
    

    print("\(indent())\(indent())]")
    // more route properties
    print("\(indent())}", terminator: "")
    if !isLast {
        print(",", terminator: "")
    }
    print("")
}

func getDayArrayString(_ array: [Bool]) -> String {
    var s = ""
    for i in (0 ..< array.count) {
        let b = array[i]
        if b {
            s += "1"
        }
        else {
            s += "0"
        }
        if i != array.count - 1 {
            s += ","
        }
    }
    
    return s
}

func getCalendarsReferencedByTrips(_ gtfs: GTFS) -> [String] {
    var calendarIds = [String]()
    for t in gtfs.trips {
        if !calendarIds.contains(t.serviceId) {
            calendarIds.append(t.serviceId)
        }
    }
    
    return calendarIds
}

func getExceptionsJsonForCalendar(_ serviceId: String, exceptionType: Int, gtfs: GTFS) -> String {
    var found = [CalendarDate]()
    for exc in gtfs.calendarDates {
        if exc.serviceId == serviceId {
            if exc.exceptionType == exceptionType {
                found.append(exc)
            }
        }
    }
    
    var result = ""
    for i in (0 ..< found.count){
        result += "\"" + found[i].date + "\""
        if i != found.count - 1 {
            result += ","
        }
        
    }
    
    return result
}


func generateJsonForCalendar(_ cal: Calendar, isLast: Bool, gtfs: GTFS) {
    let level = 2
    
    print("\(indent(level)){\"serviceId\": \"\(cal.serviceId)\", \"days\": [\(getDayArrayString(cal.daysMonToSun))], \"startDate\": \"\(cal.startDate)\", \"endDate\": \"\(cal.endDate)\",")
    print("\(indent(level)) \"addExceptions\": [")
    print("\(indent(level+1))\(getExceptionsJsonForCalendar(cal.serviceId, exceptionType: 1, gtfs: gtfs))")
    print("\(indent(level)) ],")
    print("\(indent(level)) \"removeExceptions\": [")
    print("\(indent(level+1))\(getExceptionsJsonForCalendar(cal.serviceId, exceptionType: 2, gtfs: gtfs))")
    print("\(indent(level)) ]")
    print("\(indent(level))}", terminator: "")
    
    if !isLast {
        print(",", terminator: "")
    }
    print("")
}

func generateJsonForAgency(_ agency: Agency, isLast: Bool, gtfs: GTFS) {
    // agency_id, agency_name, agency_url, agency_timezone, agency_phone, agency_lang
    let level = 2

    
    print("\(indent(level)){")
    print("\(indent(level+1))\"id\": \"\(agency.id)\",")
    print("\(indent(level+1))\"name\": \"\(agency.name)\",")
    print("\(indent(level+1))\"url\": \"\(agency.url)\",")
    print("\(indent(level+1))\"timezone\": \"\(agency.timezone)\",")
    print("\(indent(level+1))\"phone\": \"\(agency.phone)\",")
    print("\(indent(level+1))\"lang\": \"\(agency.lang)\"")
    
    print("\(indent(level))}", terminator: "")
    if !isLast {
        print(",", terminator: "")
    }
    print("")
}




func generateJson(_ gtfs: GTFS) {
    
    print("{")
    
    
    
    print("\(indent())\"agencies\": [")
    
    for agency in gtfs.agencies {
        generateJsonForAgency(agency, isLast: agency.id == gtfs.agencies.last!.id, gtfs: gtfs)
    }
    
    
    print("\(indent())],")
    
    print("\(indent())\"routes\": [")

    for route in gtfs.routes {
        generateJsonForRoute(route, isLast: route.routeId == gtfs.routes.last!.routeId, gtfs: gtfs)
    }

    print("\(indent())],")
    
    print("\(indent())\"stops\": [")
    let lastStopId = gtfs.stops.last!.id
    for stop in gtfs.stops {
        print("\(indent(2)){\"id\": \"\(stop.id)\", \"name\": \"\(stop.name)\", \"lat\": \(stop.lat), \"lng\": \(stop.lng)}", terminator: "")
        if stop.id != lastStopId {
            print(",", terminator: "")
        }
        print("")
    }
    print("\(indent())],")
    
    print("\(indent())\"calendars\": [")

    let referencedCalendars = getCalendarsReferencedByTrips(gtfs)
    var lastCalId: String = ""
    for cal in gtfs.calendars {
        if referencedCalendars.contains(cal.serviceId) {
            lastCalId = cal.serviceId
        }
    }

    for cal in gtfs.calendars {
        if referencedCalendars.contains(cal.serviceId) {
            generateJsonForCalendar(cal, isLast: (cal.serviceId == lastCalId) || (gtfs.calendars.count == 1), gtfs: gtfs)
        }
    }
    
    print("\(indent())]")
    print("}")
}

var gtfs: GTFS!

func process() {
    if (CommandLine.arguments.count > 1) {
       basePath = CommandLine.arguments[1]
    }
    
    let agencies = parseAgencies()
    let wps = parseWaypoints()
    let stops = parseStops()
    let stopTimes = parseStopTimes()
    let calendars = parseCalendars()
    let calendarDates = parseCalendarDates()
    let trips = parseTrips()
    let shapes = parseShapes()
    let routes = parseRoutes()
    
    gtfs = GTFS(agencies: agencies, stops: stops, stopTimes: stopTimes, calendars: calendars,
                calendarDates: calendarDates, trips: trips, shapes: shapes, routes: routes, waypoints: wps)
    
    generateJson(gtfs)
}

process()




