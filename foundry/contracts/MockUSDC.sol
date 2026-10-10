pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDC is ERC20Upgradeable, Ownable {
    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "MockUSDC(uint256 chainId,address baseToken)"
    );

    event AuthorizationUsed(address indexed from, address indexed to, uint256 amount, bytes32 nonce, bytes32 expires, bytes signature);
    event AuthorizationExpired(address indexed spender, bytes32 nonce);

    uint256 private _nonces[address];

    constructor(uint256 initialSupply) ERC20("MockUSDC", "mUSDC") {
        _mint(msg.sender, initialSupply);
    }

    function nonces(address owner) external view returns (uint256) {
        return _nonces[owner];
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                address(this),
                keccak256(abi.encodePacked("MockUSDC(uint256 chainId,address baseToken)", block.chainid, address(this)))
            )
        );
    }

    function _hashAuthorization(bytes32 nonce)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacking(
                keccak256("EIP712Domain(string name,string symbol,uint256 chainId,address verifyingContract)"),
                keccak256(abi.encode("MockUSDC", "mUSDC", block.chainid, address(this))),
                nonce
            )
        );
    }

    function _splitSignature(bytes32 signature)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        require(signature.size() == 65, "invalid sig length");
        r = signature[:32];
        s = signature[32:64];
        v = uint8(signature[64]);
        require(v == 27 || v == 28, "invalid v");
    }

    function _recoverOwner(uint8 v, bytes32 r, bytes32 s, bytes32 nonce)
        internal
        pure
        returns (address)
    {
        bytes32 msgHash = _hashAuthorization(nonce);
        return ECDSA.recover(msgHash, v, r, s);
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
        bytes32 nonce = nonces(owner);
        bytes32 message = _hashAuthorization(nonce);
        (address recovered, ) = _recoverOwner(v, r, s, nonce);
        require(recovered == owner, "signer mismatch");
        _nonces[owner] = nonce + 1;
        _transfer(owner, spender, amount);
        emit AuthorizationUsed(owner, spender, amount, nonce, keccak256(abi.encodePacked(owner, spender, amount, nonce, expires)), signature);
    }

    function transferWithAuthorization(
        address to,
        uint256 amount,
        bytes32 nonce,
        bytes32 expires,
        bytes memory signature
    ) external {
        require(_verifyAndExecAuth(msg.sender, to, amount, nonce, expires, signature), "invalid auth");
    }

    function _verifyAndExecAuth(
        address owner,
        address to,
        uint256 amount,
        bytes32 nonce,
        bytes32 expires,
        bytes memory signature
    ) internal returns (bool) {
        (uint8 v, bytes32 r, bytes32 s) = _splitSignature(signature);
        address recovered = _recoverOwner(v, r, s, nonce);
        require(recovered == owner, "signer mismatch");
        require(_nonces[owner] == nonce, "stale nonce");
        unchecked {
            _nonces[owner] = nonce + 1;
        }
        _transfer(owner, to, amount);
        emit AuthorizationUsed(owner, to, amount, nonce, expires, signature);
        return true;
    }

    function cancelAuthorization(bytes32 nonce) external {
        require(_nonces[msg.sender] == nonce, "no auth to cancel");
        emit AuthorizationExpired(msg.sender, nonce);
        _nonces[msg.sender] = nonce + 1;
    }
}