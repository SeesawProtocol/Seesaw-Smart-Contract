// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import './IPancakeRouter02.sol';
import './IPancakeFactory.sol';
import './IPancakePair.sol';
contract Token is Initializable, ERC20Upgradeable, AccessControlUpgradeable  {
    using SafeMathUpgradeable for uint256;
    address public _router;
    address public marketingWallet;
    address public presaleContract;
    address public publicSaleContract;
    address public lpWallet;
    address public communityWallet;
    // mapping(address => address) public _referees;
    uint256 referralPercentage; // referee get 3% of transfer amount
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bool private tradingOpen;
    mapping (address => bool) public isExcludedFromTax;
    uint16 public lpTaxPercentage;
    uint16 public communityTaxPercentage;
    uint16 public marketingTaxPercentage;
    mapping (address => bool) private _bots;

    event LogOpenTrading(bool open); 
    event LogUpdateReferralPercentage(uint256 old_val, uint256 new_val); 
    event LogUpdateTaxPercentage(uint256 old_lp_tax, uint256 old_community_tax, uint256 old_marketing_tax, uint256 new_lp_tax, uint256 new_community_tax, uint256 new_marketing_tax); 
    event LogExcludedFromTax(address[] addresses);    
    event LogIncludeFromTax(address[] addresses);    
    event LogUpdateFeeWallets(address old_lp, address old_community, address old_marketing, address lpWallet, address communityWallet, address marketingWallet);
    event LogUpdatePresaleContract(address old_presaleContract, address presaleContract);
    event LogUpdatePublicContract(address old_publicContract, address publicSaleContract);
    event Mint(address _to, uint256 _amount);
    event Burn(address _owner, uint256 _amount);
    event LogSetBots(address[] bots);
    event LogDelBots(address[] notbots);
    function initialize(
        address admin,
        string memory name,
        string memory symbol,
        uint256 initial_supply,
        address _marketingWallet,
        address _lpWallet,
        address _communityWallet,
        address router,
        uint16 _lpTaxPercentage,
        uint16 _communityTaxPercentage,
        uint16 _marketingTaxPercentage
    ) public initializer {
        __ERC20_init(name, symbol);
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _mint(admin, initial_supply);
        marketingWallet=_marketingWallet;
        lpWallet= _lpWallet;
        communityWallet= _communityWallet;
        _router=router;
        lpTaxPercentage=_lpTaxPercentage;
        communityTaxPercentage=_communityTaxPercentage;
        marketingTaxPercentage=_marketingTaxPercentage;
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function excludedFromTax(address[] memory addresses) onlyRole(DEFAULT_ADMIN_ROLE) public{
        uint8 i = 0;
        while(i < addresses.length) {            
            isExcludedFromTax[addresses[i]]=true;
            i++;
        } 
        emit LogExcludedFromTax(addresses);      
    }
    function includeInTax(address[] memory addresses) onlyRole(DEFAULT_ADMIN_ROLE) public{
        uint8 i = 0;
        while(i < addresses.length) {            
            isExcludedFromTax[addresses[i]]=false;
            i++;
        }  
        emit LogIncludeFromTax(addresses);      
    }
    function openTrading() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!tradingOpen,"trading is already open");
        tradingOpen = true;
        IPancakeRouter02 dexRouter = IPancakeRouter02(_router);

        // create pair
        address lpPair = IPancakeFactory(dexRouter.factory()).createPair(address(this), dexRouter.WETH());
        publicSaleContract=lpPair;
   
        // add the liquidity
        require(address(this).balance > 0, "Must have ETH on contract to launch");
        require(balanceOf(address(this)) > 0, "Must have Tokens on contract to launch");
        _approve(address(this), address(dexRouter), balanceOf(address(this)));
        dexRouter.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lpWallet,
            block.timestamp
        );
        emit LogOpenTrading(true);
    }
    function setReferralPercent(uint8 _referralPercentage) onlyRole(DEFAULT_ADMIN_ROLE) public{
        require(_referralPercentage>=0 && _referralPercentage<1000, "0<=,<1000");
        uint256 oldReferral=referralPercentage;
        referralPercentage=_referralPercentage;
        emit LogUpdateReferralPercentage(oldReferral, _referralPercentage);
    }
    function setTaxPercent(uint16 _lpTaxPercentage, uint16 _communityTaxPercentage, uint16 _marketingTaxPercentage) onlyRole(DEFAULT_ADMIN_ROLE) public{
        require(_lpTaxPercentage>=0 && _lpTaxPercentage<1000);
        require(_communityTaxPercentage>=0 && _communityTaxPercentage<1000);
        require(_marketingTaxPercentage>=0 && _marketingTaxPercentage<1000);
        require(_lpTaxPercentage+_communityTaxPercentage+_marketingTaxPercentage<1000);
        uint256 old_lp=lpTaxPercentage;
        uint256 old_community=communityTaxPercentage;
        uint256 old_marketing=marketingTaxPercentage;
        lpTaxPercentage=_lpTaxPercentage;
        communityTaxPercentage=_communityTaxPercentage;
        marketingTaxPercentage=_marketingTaxPercentage;
        emit LogUpdateTaxPercentage(old_lp, old_community, old_marketing, lpTaxPercentage, communityTaxPercentage, marketingTaxPercentage);
    }
    function setWallets(address _marketingWallet, address _lpWallet, address _communityWallet) public  onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        require(_marketingWallet != address(0), "_marketingWallet can not be 0 address");
        require(_lpWallet != address(0), "_lpWallet can not be 0 address");
        require(_communityWallet != address(0), "_communityWallet can not be 0 address");
        address old_marketing=marketingWallet;
        address old_lp=lpWallet;
        address old_community=communityWallet;
        marketingWallet = _marketingWallet;
        lpWallet= _lpWallet;
        communityWallet=_communityWallet;
        emit LogUpdateFeeWallets(old_lp, old_community, old_marketing, lpWallet, communityWallet, marketingWallet);
        return true;
    }


    function setPresaleContract(address _presaleContract) onlyRole(DEFAULT_ADMIN_ROLE) public returns(bool){
        require(_presaleContract != address(0), "_presaleContract can not be 0 address");
        address old_presaleContract=presaleContract;
        presaleContract = _presaleContract;
        emit LogUpdatePresaleContract(old_presaleContract, presaleContract);
        return true;
    }
    function setPublicSaleContract(address _publicSaleContract) onlyRole(DEFAULT_ADMIN_ROLE) public returns(bool){
        require(_publicSaleContract != address(0), "_publicSaleContract can not be 0 address");
        address old_publicContract=publicSaleContract;
        publicSaleContract = _publicSaleContract;
        emit LogUpdatePublicContract(old_publicContract, publicSaleContract);
        return true;
    }

    // function setReferee(address referee) public returns(bool){
    //     require(msg.sender != referee, "can not be self");
    //     _referees[msg.sender] = referee;
    //     return true;
    // }



    function mint(address _to, uint256 _amount) external onlyRole(MINTER_ROLE){
        require(_to != address(0), "_to can not be 0 address");
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    function burn(address _owner, uint256 _amount) external onlyRole(BURNER_ROLE) {
        require(_owner != address(0), "_owner can not be 0 address");
        _burn(_owner, _amount);
        emit Burn(_owner, _amount);
    }
    function setBots(address[] memory bots) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < bots.length; i++) {
            _bots[bots[i]] = true;
        }
        emit LogSetBots(bots);
    }
    
    function delBots(address[] memory notbots) public onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < notbots.length; i++) {
            _bots[notbots[i]] = false;
        }
        emit LogDelBots(notbots);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        uint256 lpTaxAmount = amount.mul(lpTaxPercentage).div(1000);
        uint256 communityTaxAmount=amount.mul(communityTaxPercentage).div(1000);
        uint256 marketingTaxAmount=amount.mul(marketingTaxPercentage).div(1000);

        require(!_bots[from] && !_bots[to]);
        if(!tradingOpen){
            require(to==publicSaleContract || to==presaleContract, "not open");
        }
        if((to==publicSaleContract && !isExcludedFromTax[from]) ||
        (from==publicSaleContract && !isExcludedFromTax[to])){                
            
            _mint(lpWallet, lpTaxAmount);
            _mint(communityWallet, communityTaxAmount);
            address[] memory tmp = new address[](2);
            IPancakeRouter02 pancakeRouter=IPancakeRouter02(_router);
            tmp[0] = address(this);
            tmp[1] = pancakeRouter.WETH();
            
            pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                marketingTaxAmount,
                0,
                tmp,
                    marketingWallet,
                block.timestamp + 3600
            );            
        }

        super._transfer(from, to, amount.sub(lpTaxAmount).sub(communityTaxAmount).sub(marketingTaxAmount));

        if((to==publicSaleContract && !isExcludedFromTax[from]) ||
            (from==publicSaleContract && !isExcludedFromTax[to])){                
            _burn(to, lpTaxAmount.add(communityTaxAmount).add(marketingTaxAmount));                    
        }
        
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

}
