//
//  Product.swift
//  FlowStackExample
//
//  Created by Charles Hieger on 6/27/23.
//

import Foundation

struct Product {
    var name: String
    var description: String
    var released: String
    var price: String
    var processor: String
    var ramMax: String
    var display: String
    var ports: String?
    var storage: String
    var osVersion: String
    var imageUrl: URL
}

extension Product: Hashable { }

extension Product: Identifiable {
    var id: String { name }
}

extension Product {
    static var appleII: Product {
        .init(name: "Apple II",
              description: "The Apple II is an 8-bit home computer and one of the world's first highly successful mass-produced microcomputer products. It was designed primarily by Steve Wozniak; Jerry Manock developed the design of Apple II's foam-molded plastic case, Rod Holt developed the switching power supply, while Steve Jobs's role in the design of the computer was limited to overseeing Jerry Manock's work on the plastic case. It was introduced by Jobs and Wozniak at the 1977 West Coast Computer Faire, and marks Apple's first launch of a personal computer aimed at a consumer market—branded toward American households rather than businessmen or computer hobbyists.",
              released: "June 1977",
              price: "$1,298 (with 4 KB memory) $2,638 (with 48 KB memory)\nSupport Status",
              processor: "MOS Technology 6502\nProcessor Speed, 1 MHz",
              ramMax: "48 KB",
              display: "280 x 192 (6 colors) or 40 x 48 (16 colors)",
              storage: "Optional Cassette Interface or Disk II floppy drive",
              osVersion: "Apple DOS 3.1 after June 1978",
              imageUrl: URL(string: "https://user-images.githubusercontent.com/11927517/249290056-fcce6546-21b8-4ecd-80f2-a32d6b0cc621.png")!)
    }

    static var appleIII: Product {
        .init(name: "Apple III",
              description: "The Apple III is a business-oriented personal computer produced by Apple Computer and released in 1980. Running the Apple SOS operating system, it was intended as the successor to the Apple II series, but was largely considered a failure in the market. It was designed to provide key features business users wanted in a personal computer: a true typewriter-style upper/lowercase keyboard (the Apple II only supported uppercase) and an 80-column display.",
              released: "May 1980",
              price: "$4,340 - $7,800",
              processor: "MOS Technology 6502A, 1.4 MHz average; 1.8 MHz maximum",
              ramMax: "512 KB with memory board replacementMemory Slots",
              display: "280 x 192 at 16 colors (with some limitations), 280 x 192 monochromatic, 560 x 192 monochromatic",
              ports: "Two serial ports\nExternal floppy port",
              storage: "Internal 143k 5-1/4 inch floppy\nExternal floppy drive",
              osVersion: "Apple Sophisticated Operating System (SOS) 1.0",
              imageUrl: URL(string: "https://user-images.githubusercontent.com/11927517/249293743-8756db8a-f9e4-49a6-95fa-e98999e52df4.png")!)
    }

    static var appleLisa: Product {
        .init(name: "Lisa 2",
              description: "The Lisa 2 was released in January 1984 and was priced lower than the original model. It used a single 400K Sony microfloppy and had as little as 512 KB of RAM. The Lisa 2/5 was a bundle that included a Lisa 2 and an external 5- or 10-megabyte hard drive. In 1984, Apple offered free upgrades to the Lisa 2/5 for all Lisa 1 owners by swapping the Twiggy drives for a 3.5-inch drive and updating the boot ROM and I/O ROM. The Lisa 2 also featured a new front faceplate with the new inlaid Apple logo and the first Snow White design language elements. The Lisa 2/10 had a 10MB internal hard drive and a standard configuration of 1 MB of RAM.",
              released: "January 1984",
              price: "$3,495 - $5,495",
              processor: "Motorola 68000, 5 MHz",
              ramMax: "2MB",
              display: "720 x 364 or 608 x 432 (with Screen Kit) at 60 Hz",
              storage: "Built-in 10 MB hard disk drive (Lisa 2/10) optional external 5 or 10 MB Apple ProFile hard disk drive (Lisa 2 and Lisa 2/5)\nMedia",
              osVersion: "Lisa Office System 3.1",
              imageUrl: URL(string: "https://user-images.githubusercontent.com/11927517/249293758-f1bb2ebf-8b45-495c-a70d-18cb5c64595e.png")!)
    }

    static var macSE: Product {
        .init(name: "Macintosh SE",
              description: "The Macintosh SE was a personal computer released by Apple Inc. in 1987 as an improvement on the original Macintosh. It featured faster processing speed, improved graphics capabilities, and the ability to hold up to four megabytes of memory. The SE also had a built-in 9-inch black-and-white CRT monitor, floppy disk drive, and an internal hard drive, making it one of the most advanced computers of its time. It was popular among businesses and home users alike due to its reliability and ease of use. The Macintosh SE also had a great impact on the design of future Apple computers, with its compact and functional design language becoming a hallmark of the brand. Despite its initial release being over 30 years ago, the Macintosh SE remains a well-regarded piece of computing history and is still in use today by retro enthusiasts.",
              released: "March 1987",
              price: "$2,898",
              processor: "Motorola 68000, 8 MHz",
              ramMax: "4MB",
              display: "512 by 342 pixels",
              storage: "4 - 30 pin SIMM (Groups of 2) Minimum Speed",
              osVersion: "System Software 2.0.1 (System 4.0, Finder 5.4) Maximum OS",
              imageUrl: URL(string: "https://user-images.githubusercontent.com/11927517/249293771-2da24ad5-4ed8-40ce-8fd8-8010bda954be.png")!)
    }

    static var macColorClassic: Product {
        .init(name: "Macintosh Color Classic",
              description: "The Macintosh Color Classic was a personal computer released by Apple in February 1993. It was an improved version of the Macintosh Classic, featuring a larger 10-inch color display with a resolution of 512x384 pixels. With the addition of color to the Classic's design, the Color Classic was praised for its vibrant and sharp graphics, and was notably Apple's first consumer-level compact color display computer. It had a similar form factor to the original Macintosh, measuring at 13.6 x 12.8 x 9.0 inches and weighing 16.5 pounds. The Color Classic also improved upon the Classic with a faster processor, which ran at 16 MHz. Like its predecessor, it was often used as a budget-friendly option for home and education users. Despite its popularity during its initial release, the Macintosh Color Classic was only produced for two years before being replaced by newer models. However, it remains highly regarded among retro computing enthusiasts for its charming design and bright display.",
              released: "February 1993",
              price: "$1,400",
              processor: "Motorola 68030, 16 MHz",
              ramMax: "10 MB",
              display: "512 by 384 pixels",
              storage: "256 KB - 512 KB (256 colors with 256 KB VRAM) (32,768 colors with 512 KB VRAM)",
              osVersion: "System 7.1 (System Enabler 401) Maximum OS",
              imageUrl: URL(string: "https://user-images.githubusercontent.com/11927517/249293764-c60804a4-8829-44e7-ad58-524a5a8731d4.png")!)
    }

    static var allProducts: [Product] {
        [.appleII, .appleIII, .appleLisa, .macSE, .macColorClassic]
    }
}
