//
//  NoScrollTest.swift
//  
//
//  Created by Zac White on 3/2/23.
//

import SwiftUI
import FlowStack

struct NoScrollTest: View {

    @State var path: FlowPath = FlowPath()

    var body: some View {
        Text("Hello, World!")
    }
}

struct NoScrollTest_Previews: PreviewProvider {
    static var previews: some View {
        NoScrollTest()
    }
}
