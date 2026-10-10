pragma solidity ^0.8.0;

contract MockUSDC {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    event AuthorizationUsed(address indexed from, address indexed to, uint256 amount, bytes32 nonce, bytes32 expires, bytes sig);
    event AuthorizationExpired(address indexed spender, bytes32 nonce);

    string public constant name_ = "MockUSDC";
    string public constant symbol_ = "mUSDC";
    uint8 public constant decimals_ = 6;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 private totalSupply_;
    mapping(address => uint256) private authNonces;

    constructor(uint256 initialSupply) {
        totalSupply_ = initialSupply;
        balanceOf[msg.sender] = initialSupply;
        _emitTransfer(address(0), msg.sender, initialSupply);
    }

    function _emitTransfer(address from, address to, uint256 value) internal {
        if (from != address(0)) {
            balanceOf[from] -= value;
        }
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "insufficient balance");
        _emitTransfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function getNonces(address owner) internal view returns (uint256) {
        return authNonces[owner];
    }

    function nonces(address owner) external view returns (uint256) {
        return authNonces[owner];
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                address(this),
                bytes32(uint256(block.chainid) << 240 | uint256(0x2fba15d5e0e638b7))  // pre-computed EIP-712 domain separator prefix
            )
        );
    }

    function _hashAuthorization(bytes32 nonce) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                address(this),
                bytes32(uint256(block.chainid) << 240 | uint256(0x2fba15d5e0e638b7)),
                nonce
            )
        );
    }

    function _recoverOwner(uint8 v, bytes32 r, bytes32 s, bytes32 nonce) internal view returns (address) {
        bytes32 msgHash = _hashAuthorization(nonce);
        return ecrecover(msgHash, v, r, s);
    }

    function permit(
        address spender,
        address owner,
        uint256 amount,
        uint256 expires,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 nonce = keccak256(abi.encodePacked("\x00Permit191", owner, amount, expires));
        address recovered = _recoverOwner(v, r, s, nonce);
        require(recovered == owner, "signer mismatch");
        authNonces[owner] = authNonces[owner] + 1;
        _emitTransfer(owner, spender, amount);
        emit AuthorizationUsed(owner, spender, amount, nonce, keccak256(abi.encodePacked(owner, spender, amount, nonce, expires)), new bytes(0));
    }

    function transferWithAuthorization(
        address to,
        uint256 amount,
        bytes32 nonce,
        bytes32 expires
    ) external {
        require(_verifyAndExecAuth(msg.sender, to, amount, nonce, expires), "invalid auth");
    }

    function _verifyAndExecAuth(
        address owner,
        address to,
        uint256 amount,
        bytes32 nonce,
        bytes32 expires
    ) internal returns (bool) {
        uint256 nun = uint256(nonce) + 1;
        require(authNonces[owner] < nun, "nonce exhausted");
        authNonces[owner] = nun;
        _emitTransfer(owner, to, amount);
        emit AuthorizationUsed(owner, to, amount, nonce, expires, new bytes(0));
        return true;
    }

    function cancelAuthorization(bytes32 nonce) external {
        require(authNonces[msg.sender] > uint256(nonce), "no auth to cancel");
        emit AuthorizationExpired(msg.sender, nonce);
        authNonces[msg.sender] = uint256(nonce) + 1;
    }
}
