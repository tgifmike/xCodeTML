struct Config {
    #if DEBUG
    static let baseURL = "http://localhost:8080"
    #else
    static let baseURL = "https://app-javabackend-5e1ae1d5056c.herokuapp.com"
    #endif
}
