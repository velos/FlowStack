//
//  URLCache+Extensions.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 7/10/23.
//

import Foundation

extension URLCache {
    static let imageCache = URLCache(memoryCapacity: 512_000_000, diskCapacity: 10_000_000_000)
}
