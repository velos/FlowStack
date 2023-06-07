//
//  SwiftUIView.swift
//  
//
//  Created by Zac White on 3/2/23.
//

import SwiftUI

enum FloatingTest: Hashable {
    case destination
}

struct InteractiveScrollViewDismissTest: View {

    @State var path: FlowPath = FlowPath()
    @SwiftUI.Environment(\.flowTransitionPercent) var percent

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(0...10, id: \.self) { index in
                    FlowLink(value: index, configuration: .init(animateFromAnchor: true)) {
                        ZStack {
                            Rectangle()
                                .foregroundColor(.red)
                                .cornerRadius(30)
                            Text("Destination \(index) \(percent)")
                        }
                        .aspectRatio(1, contentMode: .fill)
                        .padding()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .flowDestination(for: Int.self) { index in
            ScrollView {
                VStack {
                    ForEach(0...100, id: \.self) { other in
                        Text("Destination \(index)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .onTapGesture {
                if !path.isEmpty {
                    path.removeLast()
                }
            }
        }
    }
}

struct InteractiveScrollViewDismissTest_Previews: PreviewProvider {
    static var previews: some View {
        InteractiveScrollViewDismissTest()
    }
}
