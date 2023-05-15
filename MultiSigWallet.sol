// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    uint public numConfirmationsRequired;
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public isConfirmed;
    mapping(address => uint) public pendingTransactions;

    event Deposit(address indexed sender, uint amount);
    event Submission(uint indexed txId);
    event Confirmation(address indexed sender, uint indexed txId);
    event Execution(uint indexed txId);
    event ExecutionFailure(uint indexed txId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint required);

    constructor(address[] memory _owners, uint _numConfirmationsRequired) {
        require(_owners.length > 0, "At least one owner is required");
        require(
            _numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner address");
            require(!isOwner[owner], "Owner address already added");

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Sender is not an owner");
        _;
    }

    modifier txExists(uint _txId) {
        require(_txId < pendingTransactions.length, "Transaction does not exist");
        _;
    }

    modifier notConfirmed(uint _txId) {
        require(!isConfirmed[_txId][msg.sender], "Transaction already confirmed");
        _;
    }

    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes memory _data) external onlyOwner {
        uint txId = pendingTransactions.length;
        pendingTransactions[txId] = _value;
        emit Submission(txId);
    }

    function confirmTransaction(uint _txId) external onlyOwner txExists(_txId) notConfirmed(_txId) {
        isConfirmed[_txId][msg.sender] = true;
        emit Confirmation(msg.sender, _txId);
    }

    function executeTransaction(uint _txId) external onlyOwner txExists(_txId) {
        require(isConfirmedByRequiredOwners(_txId), "Transaction has not been confirmed by required owners");

        address payable to = payable(owners[_txId]);
        uint value = pendingTransactions[_txId];
        (bool success, ) = to.call{value: value}("");
        if (success) {
            emit Execution(_txId);
            delete pendingTransactions[_txId];
        } else {
            emit ExecutionFailure(_txId);
        }
    }

    function isConfirmedByRequiredOwners(uint _txId) private view returns (bool) {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (isConfirmed[_txId][owners[i]]) {
                count += 1;
                if (count == numConfirmationsRequired) {
                    return true;
                }
            }
        }
        return false;
    }

    function addOwner(address _owner) external onlyOwner {
        require(_owner != address(0), "Invalid owner address");
        require(!isOwner[_owner], "Owner address already added");

        isOwner[_owner] = true;
        owners.push
