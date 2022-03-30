import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properies
    
    // visualise planes
    var arePlanesHidden = true {
        didSet {
            planeNodes.forEach { $0.isHidden = arePlanesHidden }
        }
    }
    
    let configuration = ARWorldTrackingConfiguration()
    
    // LAst node placed by user
    var lastNode: SCNNode?
    
    //Set minimum distanse betwen objects when moved
    let minimumDistanse: Float = 0.05
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    // Set default object mode
    var objectMode: ObjectPlacementMode = .freeform
    
    /// Arrays of  objects placed
    var objetsPlaced = [SCNNode]()
    
    /// Arrays of found plans
    var planeNodes = [SCNNode]()
    
    /// The nodes for the object currectly selected by user
    var selectedNode: SCNNode?
    
    // MARK: - Metods
    
    /// Adds a node a user's touch location represented point
    /// - Parameters:
    ///   - node: the node to be added
    ///   - point: point at with user has touched the screen
    func addNode (_ node: SCNNode, at point: CGPoint) {
        guard
            let hitResult = sceneView.hitTest(point, types: .existingPlaneUsingExtent).first,
            let anchor = hitResult.anchor as? ARPlaneAnchor,
            anchor.alignment == .horizontal
        else {return}
        
        node.simdTransform = hitResult.worldTransform
        addNodeToSceneRoot(node)
    }
    
    func addNode (_ node: SCNNode, to parentNode: SCNNode) {
        // CHek the object is not to close to the previus one
        if let lastNode = lastNode {
            let lastPosition = lastNode.position
            let newPosition = node.position
            
            let x = lastPosition.x - newPosition.x
            let y = lastPosition.y - newPosition.y
            let z = lastPosition.z - newPosition.z
            
            let distanceSquare = (x * x) + (y * y) + (z * z)
            let minimumDistanceSquare =  minimumDistanse * minimumDistanse
            
            guard minimumDistanceSquare < distanceSquare else {return}
        }
        
        // Clone node to separete copies of objects
        let clonedNode = node.clone()
        
        // Fix piviot point to ground from bounding box ground coordinate
        clonedNode.simdPivot.columns.3.y = clonedNode.boundingBox.min.y
        print(#line,#function,dump(clonedNode)) // For debug
        
        // Remeber last placed node
        lastNode = clonedNode
        
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
    
    func addNodeToImage(_ node: SCNNode, at point: CGPoint) {
        guard
            let result = sceneView.hitTest(point, options: [:]).first,
            result.node.name == "image"
        else {return}
        node.transform = result.node.worldTransform
        node.eulerAngles.x  += .pi / 2 // Fix elier angle x axis
        addNodeToSceneRoot(node)
    }
    
    // Add node to scene root
    func addNodeToSceneRoot(_ node: SCNNode) {
        addNode(node, to: sceneView.scene.rootNode)
    }
    
    // Add people occlusion
    func peopleOcclusionAdd(){
        if #available(iOS 13.0, *) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        } else {
            print(#line, #function, "People occlusion is not supported, please update your iOS to version 13 or newer")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    func pressedScreen(_ touches: Set<UITouch>) {
        guard
            let touch = touches.first,
            let selectedNode = selectedNode
        else {return}
        
        let point = touch.location(in: sceneView)
        
        switch objectMode {
        case .freeform:
            addNodeInFront(selectedNode)
        case .plane:
            addNode(selectedNode, at: point)
        case .image:
            addNodeToImage(selectedNode, at: point)
        }
    }
    
    func reloadConfiguretion (reset: Bool = false) {
        // Clear objects placed
        objetsPlaced.forEach { $0.removeFromParentNode() }
        objetsPlaced.removeAll()
        
        // Clear placed planes
        planeNodes.forEach{ $0.removeFromParentNode() }
        planeNodes.removeAll()
        
        // Hide all future planes
        arePlanesHidden = true
        
        // Add people occlusion
        peopleOcclusionAdd()
        
        // Remove exisiting anchors if resert rue
        let options: ARSession.RunOptions = reset ? .removeExistingAnchors : []
        
        // Reload configuration
        configuration.detectionImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil)
        configuration.planeDetection = .horizontal
        
        sceneView.session.run(configuration, options: options)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        lastNode = nil
        pressedScreen(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        pressedScreen(touches)
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
            arePlanesHidden = true
        case 1:
            objectMode = .plane
            arePlanesHidden = false
        case 2:
            objectMode = .image
            arePlanesHidden = true
        default:
            break
        }
    }
}

// MARK: - Extensions
extension ViewController: OptionsViewControllerDelegate {
    
    func objectSelected(node: SCNNode) {
        dismiss(animated: true)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true)
        guard objectMode == .plane else {return}
        arePlanesHidden.toggle()
    }
    
    func undoLastObject() {
        if let lastObject = objetsPlaced.last {
            lastObject.removeFromParentNode()
            objetsPlaced.removeLast()
        } else {
            dismiss(animated: true)
        }
    }
    
    func resetScene() {
        reloadConfiguretion(reset: true)
        dismiss(animated: true)
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func createFloor(with size: CGSize, opacity: CGFloat = 0.25) -> SCNNode {
        
        // Set plane size
        let plane = SCNPlane(width: size.width, height: size.height)
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        // Create plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles.x -= .pi / 2
        planeNode.opacity = opacity
        
        return planeNode
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        // Put a plane above image
        let size = anchor.referenceImage.physicalSize
        print("with:\(size.width), heiht\(size.height)")
        let coverNode = createFloor(with: size, opacity: 0.1)
        coverNode.name = "image"
        
        node.addChildNode(coverNode)
    }
    
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor){
        
        let extent = anchor.extent
        let size = CGSize(width: CGFloat(extent.x), height: CGFloat(extent.z))
        let planeNode = createFloor(with: size)
        planeNode.isHidden = arePlanesHidden
        
        // Add plane node to the list of plane nodes
        planeNodes.append(planeNode)
        
        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case let imageAnchor as ARImageAnchor:
            print(#line, #function, "Detected image anchor") //Needed for debug
            nodeAdded(node, for: imageAnchor)
        case let planeAnchor as ARPlaneAnchor:
            print(#line, #function, "Detected horisontal plane anchor") //Needed for debug
            nodeAdded(node, for: planeAnchor)
        default:
            print(#line,#function, "Unknown anchor type \(anchor) detected")
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        switch anchor {
        case is ARImageAnchor:
            break
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
