import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Properies
    let configuration = ARWorldTrackingConfiguration()
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    var selectedNode: SCNNode?
    
    // MARK: - Metods
    
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
        // Clone node to separete copies of objects
        let clonedNode = node.clone()
        
        // Add cloneNode to scene
        sceneView.scene.rootNode.addChildNode(clonedNode)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard
            let touch = touches.first,
            let selectedNode = selectedNode
        else {return}
        
        print(#line, #function, dump(touch))
        
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
        sceneView.session.run(configuration)
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
