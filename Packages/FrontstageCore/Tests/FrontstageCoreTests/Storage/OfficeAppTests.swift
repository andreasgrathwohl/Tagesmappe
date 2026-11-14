import Testing
@testable import FrontstageCore

@Suite("OfficeApp")
struct OfficeAppTests {
  @Test("Office-App nur für Microsoft-Formate (FR-5.1)")
  func officeAppOnlyForMicrosoftFormats() {
    #expect(OfficeApp(fileExtension: "pptx") == .powerpoint)
    #expect(OfficeApp(fileExtension: "ppsx") == .powerpoint)
    #expect(OfficeApp(fileExtension: "doc") == .word)
    #expect(OfficeApp(fileExtension: "xlsx") == .excel)
    #expect(OfficeApp(fileExtension: "XLSX") == .excel)
    #expect(OfficeApp(fileExtension: "key") == nil)
    #expect(OfficeApp(fileExtension: "pdf") == nil)
    #expect(OfficeApp.excel.addressLengthLimit == 216 && OfficeApp.powerpoint.addressLengthLimit == 256)
  }

  @Test("Schemata der Office-URI-Schemes")
  func schemes() {
    #expect(OfficeApp.word.scheme == "ms-word")
    #expect(OfficeApp.excel.scheme == "ms-excel")
    #expect(OfficeApp.powerpoint.scheme == "ms-powerpoint")
  }
}
