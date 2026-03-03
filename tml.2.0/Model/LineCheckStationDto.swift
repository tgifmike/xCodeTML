struct LineCheckStationDto: Identifiable, Codable {

    let id: String
    let stationName: String
    let items: [LineCheckItemDto]

}
