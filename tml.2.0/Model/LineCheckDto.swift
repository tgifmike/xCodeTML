struct LineCheckDto: Codable {

    let id: String
    let username: String?
    let stations: [LineCheckStationDto]

}
