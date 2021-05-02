//
//  ViewController.swift
//  Measure003
//
//  Created by 泉芳樹 on 2021/05/02.
//

import UIKit
import RealityKit
import ARKit
import simd


class ViewController: UIViewController, ARSessionDelegate {
    private var startNode: Experience.Box?
    private var endNode: Experience.Box?
    private var lineNode: Experience.Box?

    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        arView.session.delegate = self
        
        let config = buildConfigure()
        
        arView.session.run(config)
        
        
        // Load the "Box" scene from the "Experience" Reality File
//        let boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
//        arView.scene.anchors.append(boxAnchor)
        
//        arView.environment.sceneUnderstanding.options.insert(.occlusion)
//        arView.debugOptions.insert(.showSceneUnderstanding)
    }

    func buildConfigure() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()

        configuration.sceneReconstruction = .meshWithClassification
        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal]
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
           configuration.frameSemantics = .sceneDepth
        }

        return configuration
    }


    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthData = frame.sceneDepth else {
            return
        }
//        print("#####")
//        print(depthData.confidenceMap.debugDescription)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        let pos = touch.location(in: arView)
        
        if let endNode = endNode {
            endNode.removeFromParent()
            lineNode?.removeFromParent()
        }
        
        hitTest(pos)

    }
    
    private func hitTest(_ pos: CGPoint) {
        let results = arView.hitTest(pos, types: [.existingPlane])
        guard let result = results.first else {
            return
        }
        let hitPos = result.worldTransform.position()
        
        if let startNode = startNode {
            endNode = putSphere(at: hitPos, color: .green)
            guard let endNode = endNode else {
                fatalError()
            }
            let tempX = (endNode.position.x - startNode.position.x)
            let tempY = (endNode.position.y - startNode.position.y)
            let tempZ = (endNode.position.z - startNode.position.z)
            let distance = sqrtf(tempX * tempX + tempY * tempY + tempZ * tempZ) / 2
            print("####")
            print("distance \(distance) [m]")
            
            lineNode = drawLine(from: startNode, to: endNode, length: distance)
            
            print(String(format: "Distance: %.2f [m]", distance) )
//            statusLabel.text = String(format: "Distance: %.2f [m]", distance)
            
        } else {
            startNode = putSphere(at: hitPos, color: .blue)
            
//            statusLabel.text = "Tap an end point"
        }
    }
    
    
    private func putSphere(at pos: SCNVector3, color: UIColor) -> Experience.Box {
//        let node = SCNNode.sphereNode(color: color)
        let boxAnchor = try! Experience.loadBox()
        boxAnchor.stopAllAnimations()
        boxAnchor.scale.x = 0.1
        boxAnchor.scale.y = 0.1
        boxAnchor.scale.z = 0.1
        boxAnchor.position.x = pos.x
        boxAnchor.position.y = pos.y
        boxAnchor.position.z = pos.z

        arView.scene.addAnchor(boxAnchor) //.rootNode.addChildNode(node)
//        node.position = pos
        return boxAnchor
    }

    private func drawLine(from: Experience.Box, to: Experience.Box, length: Float) -> Experience.Box {
        let lineNode = try! Experience.loadBox()
        from.addChild(lineNode)
        lineNode.stopAllAnimations()
        lineNode.scale.x = 0.1
        lineNode.scale.y = 0.1
        lineNode.scale.z = 0.1

        lineNode.position.x = 0
        lineNode.position.y = 0
        lineNode.position.z = -length / 2
        from.look(at: to.position, from: from.position, relativeTo: lineNode)
//        from.look(at: to.position)
        return lineNode
    }

}


extension ARCamera.TrackingState {
    public var description: String {
        switch self {
        case .notAvailable:
            return "TRACKING UNAVAILABLE"
        case .normal:
            return "TRACKING NORMAL"
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                return "TRACKING LIMITED\nToo much camera movement"
            case .insufficientFeatures:
                return "TRACKING LIMITED\nNot enough surface detail"
            case .initializing:
                return "TRACKING LIMITED\nInitialization in progress"
            case .relocalizing:
                return "TRACKING LIMITED\nRelocalization in progress"
            @unknown default:
                fatalError()
            }
        }
    }
}

extension UIColor {
    class var arBlue: UIColor {
        get {
            return UIColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1)
        }
    }
}
extension ARPlaneAnchor {
    
    @discardableResult
    func addPlaneNode(on node: SCNNode, geometry: SCNGeometry, contents: Any) -> SCNNode {
        guard let material = geometry.materials.first else {
            fatalError()
        }
        if let program = contents as? SCNProgram {
            material.program = program
        } else {
            material.diffuse.contents = contents
        }
        
        let planeNode = SCNNode(geometry: geometry)
        
        DispatchQueue.main.async(execute: {
            node.addChildNode(planeNode)
        })
        return planeNode
    }
    func addPlaneNode(on node: SCNNode, contents: Any) {
        let geometry = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = addPlaneNode(on: node, geometry: geometry, contents: contents)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
    }
    
    func findPlaneNode(on node: SCNNode) -> SCNNode? {
        for childNode in node.childNodes {
            if childNode.geometry as? SCNPlane != nil {
                return childNode
            }
        }
        return nil
    }
    
    func updatePlaneNode(on node: SCNNode) {
        DispatchQueue.main.async(execute: {
            guard let plane = self.findPlaneNode(on: node)?.geometry as? SCNPlane else {
                return
            }
            guard !PlaneSizeEqualToExtent(plane: plane, extent: self.extent) else { return }
            plane.width = CGFloat(self.extent.x)
            plane.height = CGFloat(self.extent.z)
        })
    }
}

fileprivate func PlaneSizeEqualToExtent(plane: SCNPlane, extent: vector_float3) -> Bool {
    if plane.width != CGFloat(extent.x) || plane.height != CGFloat(extent.z) {
        return false
    } else {
        return true
    }
}


func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
}
extension matrix_float4x4 {
    func position() -> SCNVector3 {
        let mat = SCNMatrix4(self)
        return SCNVector3(mat.m41, mat.m42, mat.m43)
    }
}
extension SCNNode {
    class func sphereNode(color: UIColor) -> SCNNode {
        let geometry = SCNSphere(radius: 0.01)
        geometry.materials.first?.diffuse.contents = color
        return SCNNode(geometry: geometry)
    }
    
    class func lineNode(length: CGFloat, color: UIColor) -> SCNNode {
        let geometry = SCNCapsule(capRadius: 0.004, height: length)
        geometry.materials.first?.diffuse.contents = color
        let line = SCNNode(geometry: geometry)
        
        let node = SCNNode()
        node.eulerAngles = SCNVector3Make(Float.pi/2, 0, 0)
        node.addChildNode(line)
        
        return node
    }
}
