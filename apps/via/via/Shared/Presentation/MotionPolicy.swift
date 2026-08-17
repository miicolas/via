import Foundation

enum MotionPolicy {
    static func beamEnabled(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}
