//
//  DisableInteractiveDismissTest.swift
//  
//
//  Created by Zac White on 3/23/23.
//

import SwiftUI
import FlowStack

struct DisableInteractiveDismissTest: View {

    @State var disable: Bool = false

    var body: some View {
        ZStack {
            Color.green

            VStack {
                Button("Disable / Enable") {
                    disable.toggle()
                }

                if disable {
                    Text("Disabled")
                        .flowInteractiveDismissDisabled()
                } else {
                    Text("Enabled")
                }
            }
        }
    }
}

struct NavigationDismissTest_Previews: PreviewProvider {
    static var previews: some View {
        DisableInteractiveDismissTest()
    }
}
