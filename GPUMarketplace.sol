// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GPUContract {
    address public owner;
    uint256 public providerCollateral;

    enum GPUStatus { Available, InUse }

    struct GPU {
        uint256 id;
        string name;
        uint256 price;
        GPUStatus status;
        address currentConsumer;
    }

    struct Provider {
        address providerAddress;
        uint256 collateral;
        uint256 reputation;
        bool isRegistered;
    }

    struct Request {
        address consumerAddress;
        uint256 gpuRequirements; // This field should be in the Request struct, not Provider
        uint256 duration;
        uint256 payment;
        Status status;
    }

    mapping(uint256 => GPU) public GPUs;
    mapping(address => Provider) public providers;
    Request[] public requests;
    uint256 public gpuCount;

    enum Status { Open, Matched, Deployed, Completed }

    event GPURegistered(uint256 id, string name, uint256 price);
    event GPURequested(uint256 indexed gpuId, address indexed consumer);
    event GPUReleased(uint256 indexed gpuId, address indexed consumer);
    event PaymentDeposited(uint256 amount);
    event PaymentReleased(address indexed provider, uint256 amount);
    event ProviderRegistered(address indexed provider);
    event RequestCreated(address indexed consumer, uint256 requestId);
    event RequestMatched(uint256 indexed requestId);
    event RequestDeployed(uint256 indexed requestId);
    event RequestCompleted(uint256 indexed requestId);

    constructor() {
        owner = msg.sender;
        providerCollateral = 10 ether; // Assumption: Collateral required from providers
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier gpuExists(uint256 gpuId) {
        require(gpuId > 0 && gpuId <= gpuCount, "GPU does not exist");
        _;
    }

    modifier gpuAvailable(uint256 gpuId) {
        require(GPUs[gpuId].status == GPUStatus.Available, "GPU is not available");
        _;
    }

    modifier gpuInUse(uint256 gpuId) {
        require(GPUs[gpuId].status == GPUStatus.InUse, "GPU is not in use");
        _;
    }

    modifier onlyRegisteredProvider() {
        require(providers[msg.sender].isRegistered, "Provider not registered");
        _;
    }

    function registerGPU(string memory name, uint256 price) external onlyOwner {
        gpuCount++;
        GPUs[gpuCount] = GPU(gpuCount, name, price, GPUStatus.Available, address(0));
        emit GPURegistered(gpuCount, name, price);
    }

    function requestGPU(uint256 gpuId) external payable gpuExists(gpuId) gpuAvailable(gpuId) {
        require(msg.value >= GPUs[gpuId].price, "Insufficient payment");
        GPUs[gpuId].status = GPUStatus.InUse;
        GPUs[gpuId].currentConsumer = msg.sender;
        emit GPURequested(gpuId, msg.sender);
    }

    function releaseGPU(uint256 gpuId) external gpuExists(gpuId) gpuInUse(gpuId) {
        require(GPUs[gpuId].currentConsumer == msg.sender, "Not the GPU's current consumer");
        GPUs[gpuId].status = GPUStatus.Available;
        GPUs[gpuId].currentConsumer = address(0);
        emit GPUReleased(gpuId, msg.sender);
    }

    function depositProviderCollateral() external payable onlyRegisteredProvider {
        require(msg.value == providerCollateral, "Incorrect collateral amount");
        emit PaymentDeposited(msg.value);
    }

    function releaseProviderPayment(uint256 amount) external onlyRegisteredProvider {
        payable(owner).transfer(amount);
        emit PaymentReleased(owner, amount);
    }

    function registerProvider(uint256 _collateral) external {
        require(!providers[msg.sender].isRegistered, "Provider already registered");
        providers[msg.sender] = Provider(msg.sender, _collateral, 0, true);
        emit ProviderRegistered(msg.sender);
    }

    function createRequest(uint256 _gpuRequirements, uint256 _duration, uint256 _payment) external {
        require(providers[msg.sender].isRegistered, "Provider not registered");
        requests.push(Request(msg.sender, _gpuRequirements, _duration, _payment, Status.Open));
        emit RequestCreated(msg.sender, requests.length - 1);
    }

    function matchRequest(uint256 _requestId) external onlyRegisteredProvider {
        require(_requestId < requests.length, "Invalid request ID");
        require(requests[_requestId].status == Status.Open, "Request not open");
        require(providers[msg.sender].collateral >= requests[_requestId].payment, "Insufficient collateral");

        requests[_requestId].status = Status.Matched;
        emit RequestMatched(_requestId);
    }

    function deployRequest(uint256 _requestId) external onlyRegisteredProvider {
        require(_requestId < requests.length, "Invalid request ID");
        require(requests[_requestId].status == Status.Matched, "Request not matched");

        // Perform GPU deployment logic here

        requests[_requestId].status = Status.Deployed;
        emit RequestDeployed(_requestId);
    }

    function completeRequest(uint256 _requestId) external onlyRegisteredProvider {
        require(_requestId < requests.length, "Invalid request ID");
        require(requests[_requestId].status == Status.Deployed, "Request not deployed");

        // Perform completion logic here

        requests[_requestId].status = Status.Completed;
        emit RequestCompleted(_requestId);
    }

    // Fallback function to receive payments
    receive() external payable {}

    // Withdraw any remaining contract balance (for emergency)
    function withdrawBalance() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}
