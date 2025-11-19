// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DemoAsset
 * @notice Simple ERC20 token for demonstrating state changes on Rayls L1
 *
 * This is a simple tokenized asset that generates state changes
 * which get captured in Merkle roots and anchored to Ethereum.
 */
contract DemoAsset is ERC20, Ownable {
    
    /* EVENTS*/

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    /*CONSTRUCTOR*/

    /**
     * @param name Token name
     * @param symbol Token symbol
     * @param initialSupply Initial supply to mint to deployer
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
            emit TokensMinted(msg.sender, initialSupply);
        }
    }

    /*/// MINTING & BURNING ///*/

    /**
     * @notice Mint tokens to an address
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @notice Burn tokens from an address (with approval)
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external {
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }
}
