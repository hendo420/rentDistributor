// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RentContract is ERC721 {
    using SafeMath for uint256;

    IERC20 public usdtToken;
    uint256 public constant GRACE_PERIOD = 5 days;
    uint256 public constant LATE_FEE = 25 * 10**18; // In USDT

    struct Property {
        uint256 id;
        uint256 rent;
        uint256 lastPaid;
        uint256 dueDate;
    }

    mapping(uint256 => Property) public properties;
    uint256 private nextPropertyId;

    event RentPaid(address indexed renter, uint256 indexed propertyId, uint256 amount);
    event RentChanged(uint256 indexed propertyId, uint256 newRent);
    event Eviction(uint256 indexed propertyId);

    constructor(address _usdtTokenAddress) ERC721("RentProperty", "RPT") {
        usdtToken = IERC20(_usdtTokenAddress);
        nextPropertyId = 1;
    }

    function registerProperty(uint256 _rent) external {
        uint256 propertyId = nextPropertyId;
        _safeMint(msg.sender, propertyId);
        properties[propertyId] = Property({
            id: propertyId,
            rent: _rent,
            lastPaid: 0,
            dueDate: block.timestamp.add(30 days)
        });
        nextPropertyId = nextPropertyId.add(1);
    }

    function changeRent(uint256 _propertyId, uint256 _newRent) external {
        require(_isApprovedOrOwner(msg.sender, _propertyId), "Not owner or approved");
        properties[_propertyId].rent = _newRent;
        emit RentChanged(_propertyId, _newRent);
    }

    function payRent(uint256 _propertyId, uint256 _amount) external {
        Property storage property = properties[_propertyId];
        require(property.id != 0, "Property does not exist");
        require(block.timestamp <= property.dueDate.add(GRACE_PERIOD), "Rent payment is too late");

        uint256 lateDays = block.timestamp > property.dueDate ? block.timestamp.sub(property.dueDate).div(1 days) : 0;
        uint256 totalRent = property.rent.add(lateDays.mul(LATE_FEE));
        require(_amount >= totalRent, "Insufficient rent amount");

        usdtToken.transferFrom(msg.sender, address(this), _amount);
        property.lastPaid = block.timestamp;
        property.dueDate = property.dueDate.add(30 days);

        emit RentPaid(msg.sender, _propertyId, _amount);
    }

    function claimRent(uint256 _propertyId) external {
        require(_isApprovedOrOwner(msg.sender, _propertyId), "Not owner or approved");

        Property storage property = properties[_propertyId];
        uint256 balance = usdtToken.balanceOf(address(this));
        uint256 rent = property.rent.add(property.lastPaid > 0 ? LATE_FEE.mul(block.timestamp.sub(property.lastPaid).div(1 days)) : 0);

        require(balance >= rent, "Not enough rent to claim");

        usdtToken.transfer(msg.sender, rent);
    }

    function evict(uint256 _propertyId) external {
        require(_isApprovedOrOwner(msg.sender, _propertyId), "Not owner or approved");
    	Property storage property = properties[_propertyId];
    	property.lastPaid = 0;
    	property.dueDate = block.timestamp.add(30 days);
    	emit Eviction(_propertyId);
	}

}