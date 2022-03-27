import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properies
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    /// Arrays of  objects placed
    var objetsPlaced = [SCNNode]()
    
    /// Arrays of found plans
    var planeNodes = [SCNNode]()
    
    /// The nodes for the object currectly selected by user
    var selectedNode: SCNNode?
    
    // MARK: - Metods
    
    func addNode (_ node: SCNNode, to parentNode: SCNNode) {
        // Clone node to separete copies of objects
        let clonedNode = node.clone()
        
        // Remember object placed for undo
        objetsPlaced.append(clonedNode)
        
        // Add cloneNode to scene
        parentNode.addChildNode(clonedNode)
    }
    
    /// Add node in 20cm front of camera
    /// - Parameter node: node of object to add
    func addNodeInFront (_ node: SCNNode) {
        // Get camera frame
        guard let frame = sceneView.session.currentFrame else {return}
        
        // Get transtorm properiry from camera frame
        let transform = frame.camera.transform
        
        // Create translation matrix
        var translation = matrix_identity_float4x4
        
        // Translate by 20cm on z axis
        translation.columns.3.z = -0.2
        
        // TASK: - Read documentation of  translation matrix
        // Rotate by pi / 2 on z axis
        translation.columns.0.x = 0
        translation.columns.1.x = -1
        translation.columns.0.y = 1
        translation.columns.1.y = 0
        
        // Assign transform to node
        node.simdTransform = matrix_multiply(transform, translation)
        
        // Add node to the scene
        addNodeToSceneRoot(node)
    }
    
    // Add node to ccene root
    func addNodeToSceneRoot(_ node: SCNNode) {
        addNode(node, to: sceneView.scene.rootNode)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    func reloadConfiguretion () {
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard
            let touch = touches.first,
            let selectedNode = selectedNode
        else {return}
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .plane:
            break
        case .image:
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguretion()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - Actions
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
    }
}

// MARK: - Extensions
extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
    }
    
    func undoLastObject() {
    }
    
    func resetScene() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        
        // Get estimated plane size
        let extent = planeAnchor.extent
        let with = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        // Ste plane size
        let plane = SCNPlane(width: with, height: height)
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        // Create plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x -= .pi / 2
        planeNode.opacity = 0.2
        
        return planeNode
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor){
        let planeNode = createFloor(planeAnchor: anchor)
        
        // Add plane node to the list of plane nodes
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case let planeAnchor as ARPlaneAnchor:
            print(#line, #function, "Detected horisontal plane anchor") //Needed for debug
            nodeAdded(node, for: planeAnchor)
        default:
            print(#line,#function, "Unknown anchor type \(anchor) detected")
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case let planeAnchor as ARPlaneAnchor:
            updateFloor(for: node, anchor: planeAnchor)
        default:
            print(#line,#function, "Unknown anchor type \(anchor) updated")
        }
    }
    
    func updateFloor (for node: SCNNode, anchor: ARPlaneAnchor){
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {return}
        
        // Get estimated plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        
        // Position plane in hte center
        planeNode.simdPosition = anchor.center
    }
}
