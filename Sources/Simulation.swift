import Foundation

func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, x)) }
func approach(_ x: Double, _ target: Double, _ rate: Double, _ dt: Double) -> Double {
    x + (target - x) * (1 - exp(-rate * dt))
}

struct Helm {
    var throttle = 0.0
    var rudder = 0.0
    var dive = 0.0
}

struct Voyage {
    var x = 0.0, z = 0.0, heading = 0.0, depth = 0.0
    var speed = 0.0, verticalSpeed = 0.0, pitch = 0.0, roll = 0.0
    var throttle = 0.0, targetDepth = 0.0, distance = 0.0, elapsed = 0.0
    var rudder = 0.0
    var clearance: Double { 235 - depth }
    var knots: Double { speed / 0.514444 }
    var bearing: Double { (heading * 180 / .pi).truncatingRemainder(dividingBy: 360) + (heading < 0 ? 360 : 0) }
    mutating func step(_ dt: Double, helm: Helm) {
        let dt = clamp(dt, 0, 0.05)
        elapsed += dt
        throttle = clamp(throttle + helm.throttle * dt * 0.32, -0.3, 1)
        targetDepth = clamp(targetDepth + helm.dive * dt * 14, 0, 220)
        let maxSpeed = depth > 8 ? 7.2 : 9.2
        speed = approach(speed, throttle * maxSpeed, 0.23, dt)
        rudder = approach(rudder, helm.rudder, 2.3, dt)
        let steer = rudder * 0.24 * min(abs(speed) / 3 + 0.12, 1) * (speed < -0.1 ? -1 : 1)
        heading += steer * dt
        heading = (heading + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let desiredVertical = clamp((targetDepth - depth) * 0.25, -3, 3)
        verticalSpeed = approach(verticalSpeed, desiredVertical, 0.7, dt)
        depth = clamp(depth + verticalSpeed * dt, 0, 220)
        pitch = approach(pitch, -verticalSpeed * 0.055, 1.2, dt)
        roll = approach(roll, -steer * speed * 0.05, 1.5, dt)
        x += sin(heading) * speed * dt
        z -= cos(heading) * speed * dt
        distance += abs(speed) * dt
    }
}

func runSimulationTests() {
    var v = Voyage()
    for _ in 0..<1800 { v.step(1.0 / 60, helm: Helm(throttle: 1)) }
    precondition(v.knots > 17 && v.knots < 18, "Surface speed")
    precondition(v.z < -150 && abs(v.x) < 0.001, "Forward movement")
    for _ in 0..<600 { v.step(1.0 / 60, helm: Helm(rudder: 1, dive: 1)) }
    precondition(v.heading > 1 && v.depth > 10, "Turning and diving")
    for _ in 0..<12000 { v.step(1.0 / 60, helm: Helm(dive: 1)) }
    precondition(v.depth <= 220 && v.depth > 219, "Safe depth clamp")
    v.targetDepth = 0
    for _ in 0..<9000 { v.step(1.0 / 60, helm: Helm()) }
    precondition(v.depth < 0.01, "Surface recovery")
    for _ in 0..<2400 { v.step(1.0 / 60, helm: Helm(throttle: -1)) }
    precondition(v.speed < -2 && v.throttle == -0.3, "Reverse propulsion")
    precondition(v.x.isFinite && v.z.isFinite && v.heading >= 0 && v.heading < 2 * .pi)
    print("PASS — propulsion, navigation, turning, diving, depth limit, surfacing, reverse")
}
