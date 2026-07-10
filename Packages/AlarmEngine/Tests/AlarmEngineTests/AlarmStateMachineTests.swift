import Testing
@testable import AlarmEngine

@Suite("AlarmStateMachine")
struct AlarmStateMachineTests {
    @Test("the happy path: scheduled → ringing → proof → dismissed")
    func happyPath() {
        var machine = AlarmStateMachine()
        #expect(machine.handle(.fire) == .ringing)
        #expect(machine.handle(.beginProof) == .proofInProgress)
        #expect(machine.handle(.proofSucceeded) == .dismissed)
        #expect(machine.state == .dismissed)
    }

    @Test("failed proof returns to ringing and can retry")
    func proofRetry() {
        var machine = AlarmStateMachine(state: .proofInProgress)
        #expect(machine.handle(.proofFailed) == .ringing)
        #expect(machine.handle(.beginProof) == .proofInProgress)
        #expect(machine.handle(.proofSucceeded) == .dismissed)
    }

    @Test("emergency exit is reachable from ringing and from proofInProgress")
    func emergencyExitAlwaysReachable() {
        var fromRinging = AlarmStateMachine(state: .ringing)
        #expect(fromRinging.handle(.emergencyExit) == .emergencyExited)

        var fromProof = AlarmStateMachine(state: .proofInProgress)
        #expect(fromProof.handle(.emergencyExit) == .emergencyExited)
    }

    @Test("expiry is reachable from ringing and from proofInProgress")
    func expiry() {
        var fromRinging = AlarmStateMachine(state: .ringing)
        #expect(fromRinging.handle(.expire) == .expired)

        var fromProof = AlarmStateMachine(state: .proofInProgress)
        #expect(fromProof.handle(.expire) == .expired)
    }

    @Test("terminal states absorb every event", arguments: [AlarmState.dismissed, .emergencyExited, .expired])
    func terminalStatesAbsorbEverything(terminal: AlarmState) {
        for event in AlarmEvent.allCases {
            var machine = AlarmStateMachine(state: terminal)
            #expect(machine.handle(event) == nil)
            #expect(machine.state == terminal)
        }
    }

    @Test("the transition table is exactly the eight legal transitions")
    func transitionTableIsExhaustive() {
        var legal: [(AlarmState, AlarmEvent, AlarmState)] = []
        for state in AlarmState.allCases {
            for event in AlarmEvent.allCases {
                if let next = AlarmStateMachine.nextState(from: state, on: event) {
                    legal.append((state, event, next))
                }
            }
        }
        #expect(legal.count == 8)
        // Invalid examples that must stay invalid:
        #expect(AlarmStateMachine.nextState(from: .scheduled, on: .beginProof) == nil)
        #expect(AlarmStateMachine.nextState(from: .scheduled, on: .expire) == nil)
        #expect(AlarmStateMachine.nextState(from: .scheduled, on: .emergencyExit) == nil)
        #expect(AlarmStateMachine.nextState(from: .ringing, on: .fire) == nil)
        #expect(AlarmStateMachine.nextState(from: .ringing, on: .proofSucceeded) == nil)
        #expect(AlarmStateMachine.nextState(from: .proofInProgress, on: .fire) == nil)
    }

    @Test("an invalid event leaves the machine untouched")
    func invalidEventIsANoOp() {
        var machine = AlarmStateMachine()
        #expect(machine.handle(.proofSucceeded) == nil)
        #expect(machine.state == .scheduled)
    }
}
