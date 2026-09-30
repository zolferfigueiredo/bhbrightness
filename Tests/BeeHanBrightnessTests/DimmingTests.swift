import Testing
@testable import BeeHanBrightness

@Test func stepsGetDarker() {
    #expect(dims == dims.sorted(by: >) && dims.first! < 1 && dims.last! > 0)
}

@Test func downStartsSubZeroOnlyAtTheLowestStep() {
    #expect(press(0, 0.5, up: false) == nil)
    #expect(press(0, 0.125, up: false) == nil)
    #expect(press(0, 0.1, up: false) == 1)
    #expect(press(0, dot, up: false) == 1)
    #expect(press(0, 0.0624999, up: false) == 1)
    #expect(press(0, 0, up: false) == 1)
}

@Test func downGoesDeeperUntilTheLastStep() {
    #expect(press(3, dot, up: false) == 4)
    #expect(press(dims.count, dot, up: false) == dims.count)
}

@Test func upWalksBackOutThenLeavesItToMacOS() {
    #expect(press(3, dot, up: true) == 2)
    #expect(press(1, dot, up: true) == 0)
    #expect(press(0, dot, up: true) == nil)
    #expect(press(0, 0, up: true) == nil)
    #expect(press(0, 1, up: true) == nil)
}
