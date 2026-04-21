//
//  AppSettings.swift
//  tml.2.0
//
//  Created by mike on 4/21/26.
//

import SwiftUI
import Combine

class AppSettings: ObservableObject {

    @Published var completionMode: LineCheckCompletionMode = .requireAllItemsCompleted
}
