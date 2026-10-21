//
//  RoutinesWidgetBundle.swift
//  RoutinesWidget
//
//  Created by Laura Siedenhans on 21.10.26.
//

import WidgetKit
import SwiftUI

@main
struct RoutinesWidgetBundle: WidgetBundle {
    var body: some Widget {
        RoutinesWidget()
        RoutinesWidgetControl()
        RoutinesWidgetLiveActivity()
    }
}
