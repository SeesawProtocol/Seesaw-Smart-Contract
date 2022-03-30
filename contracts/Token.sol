//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11;
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./IPancakeRouter02.sol";
import "./IPancakeFactory.sol";
import "./IPancakePair.sol";

contract Token is Initializable, IERC20Upgradeable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;
    address admin;
    address payable public marketingAddress; // Marketing Address
    mapping(address => bool) public bots;

    address payable public liquidityAddress; // Liquidity Address
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromFee;

    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private constant BUY = 1;
    uint256 private constant SELL = 2;
    uint256 private constant TRANSFER = 3;
    uint256 private buyOrSellSwitch;

    // these values are pretty much arbitrary since they get overwritten for every txn, but the placeholders make it easier to work with current contract.
    uint256 private _taxFee;
    uint256 private _previousTaxFee;

    uint256 private _liquidityFee;
    uint256 private _previousLiquidityFee;

    uint256 public _buyTaxFee;
    uint256 public _buyLiquidityFee;
    uint256 public _buyMarketingFee;

    uint256 public _sellTaxFee;
    uint256 public _sellLiquidityFee;
    uint256 public _sellMarketingFee;

    uint256 public liquidityActiveBlock; // 0 means liquidity is not active yet
    uint256 public tradingActiveBlock; // 0 means trading is not active

    bool public limitsInEffect;
    bool public tradingActive;
    bool public swapEnabled;

    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    // Anti-bot and anti-whale mappings and variables
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
    bool public transferDelayEnabled;

    uint256 private _liquidityTokensToSwap;
    uint256 private _marketingTokensToSwap;

    bool private gasLimitActive;
    uint256 private gasPriceLimit;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 public minimumTokensBeforeSwap;
    uint256 public maxTransactionAmount;
    uint256 public maxWallet;

    IPancakeRouter02 public pancakeRouter;
    address public pancakePair;

    bool inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;

    event RewardLiquidityProviders(uint256 tokenAmount);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SwapETHForTokens(uint256 amountIn, address[] path);

    event SwapTokensForETH(uint256 amountIn, address[] path);

    event ExcludedMaxTransactionAmount(
        address indexed account,
        bool isExcluded
    );
    event LogAddBots(address[] bots);
    event LogRemoveBots(address[] notbots);
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function initialize(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        address _pancakeV2RouterAddress,
        bool[6] memory _bool_params,
        uint256[13] memory _uint_params
    ) public initializer {
        _name = __name;
        _symbol = __symbol;
        _decimals = __decimals;
        __AccessControl_init();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        admin = msg.sender;
        _tTotal = _uint_params[0];
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[_msgSender()] = _rTotal;

        maxTransactionAmount = _uint_params[1];
        minimumTokensBeforeSwap = _uint_params[2];
        maxWallet = _uint_params[3];
        _buyTaxFee = _uint_params[4];
        _buyLiquidityFee = _uint_params[5];
        _buyMarketingFee = _uint_params[6];

        _sellTaxFee = _uint_params[7];
        _sellLiquidityFee = _uint_params[8];
        _sellMarketingFee = _uint_params[9];

        liquidityActiveBlock = _uint_params[10]; // 0 means liquidity is not active yet
        tradingActiveBlock = _uint_params[11]; // 0 means trading is not active

        limitsInEffect = _bool_params[0];
        tradingActive = _bool_params[1];
        swapEnabled = _bool_params[2];
        transferDelayEnabled = _bool_params[3];

        gasLimitActive = _bool_params[4];
        gasPriceLimit = _uint_params[12];
        swapAndLiquifyEnabled = _bool_params[5];

        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(
            _pancakeV2RouterAddress
        );

        address _pancakePair = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), _pancakeRouter.WETH());

        pancakeRouter = _pancakeRouter;
        pancakePair = _pancakePair;

        marketingAddress = payable(msg.sender); // update to marketing address
        liquidityAddress = payable(address(0xdead)); // update to a liquidity wallet if you don't want to burn LP tokens generated by the contract.

        _setAutomatedMarketMakerPair(_pancakePair, true);

        _isExcludedFromFee[_msgSender()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[liquidityAddress] = true;

        excludeFromMaxTransaction(_msgSender(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(_pancakeRouter), true);
        excludeFromMaxTransaction(address(0xdead), true);

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcluded[account];
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    // once enabled, can never be turned off
    function enableTrading() external onlyRole(DEFAULT_ADMIN_ROLE) {
        tradingActive = true;
        swapAndLiquifyEnabled = true;
        tradingActiveBlock = block.number;
    }

    function minimumTokensBeforeSwapAmount() external view returns (uint256) {
        return minimumTokensBeforeSwap;
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            pair != pancakePair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        excludeFromMaxTransaction(pair, value);
        if (value) {
            excludeFromReward(pair);
        }
        if (!value) {
            includeInReward(pair);
        }
    }

    function setProtectionSettings(bool antiGas)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        gasLimitActive = antiGas;
    }

    function setGasPriceLimit(uint256 gas)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(gas >= 300);
        gasPriceLimit = gas * 1 gwei;
    }

    // disable Transfer delay
    function disableTransferDelay()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        transferDelayEnabled = false;
        return true;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
        external
        view
        returns (uint256)
    {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    // for one-time airdrop feature after contract launch
    function airdropToWallets(
        address[] memory airdropWallets,
        uint256[] memory amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            airdropWallets.length == amount.length,
            "airdropToWallets:: Arrays must be the same length"
        );
        removeAllFee();
        buyOrSellSwitch = TRANSFER;
        for (uint256 i = 0; i < airdropWallets.length; i++) {
            address wallet = airdropWallets[i];
            uint256 airdropAmount = amount[i];
            _tokenTransfer(msg.sender, wallet, airdropAmount);
        }
        restoreAllFee();
    }

    // remove limits after token is stable - 30-60 minutes
    function removeLimits()
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool)
    {
        limitsInEffect = false;
        gasLimitActive = false;
        transferDelayEnabled = false;
        return true;
    }

    function tokenFromReflection(uint256 rAmount)
        public
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function excludeFromReward(address account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(!_isExcluded[account], "Account is already excluded");
        require(
            _excluded.length + 1 <= 50,
            "Cannot exclude more than 50 accounts.  Include a previously excluded address."
        );
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
        emit ExcludedMaxTransactionAmount(updAds, isEx);
    }

    function includeInReward(address account)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!bots[from] && !bots[to]);

        if (!tradingActive) {
            require(
                _isExcludedFromFee[from] || _isExcludedFromFee[to],
                "Trading is not active yet."
            );
        }

        if (limitsInEffect) {
            if (
                from != admin &&
                to != admin &&
                to != address(0) &&
                to != address(0xdead) &&
                !inSwapAndLiquify
            ) {
                // only use to prevent sniper buys in the first blocks.
                if (gasLimitActive && automatedMarketMakerPairs[from]) {
                    require(
                        tx.gasprice <= gasPriceLimit,
                        "Gas price exceeds limit."
                    );
                }

                // at launch if the transfer delay is enabled, ensure the block timestamps for purchasers is set -- during launch.
                if (transferDelayEnabled) {
                    if (
                        to != admin &&
                        to != address(pancakeRouter) &&
                        to != address(pancakePair)
                    ) {
                        require(
                            _holderLastTransferTimestamp[tx.origin] <
                                block.number,
                            "_transfer:: Transfer Delay enabled.  Only one purchase per block allowed."
                        );
                        _holderLastTransferTimestamp[tx.origin] = block.number;
                    }
                }

                //when buy
                if (
                    automatedMarketMakerPairs[from] &&
                    !_isExcludedMaxTransactionAmount[to]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Buy transfer amount exceeds the maxTransactionAmount."
                    );
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "Cannot exceed max wallet"
                    );
                }
                //when sell
                else if (
                    automatedMarketMakerPairs[to] &&
                    !_isExcludedMaxTransactionAmount[from]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Sell transfer amount exceeds the maxTransactionAmount."
                    );
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "Cannot exceed max wallet"
                    );
                }
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinimumTokenBalance = contractTokenBalance >=
            minimumTokensBeforeSwap;

        // Sell tokens for ETH
        if (
            !inSwapAndLiquify &&
            swapAndLiquifyEnabled &&
            balanceOf(pancakePair) > 0 &&
            overMinimumTokenBalance &&
            automatedMarketMakerPairs[to]
        ) {
            swapBack();
        }

        removeAllFee();

        buyOrSellSwitch = TRANSFER;

        // If any account belongs to _isExcludedFromFee account then remove the fee
        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            // Buy
            if (automatedMarketMakerPairs[from]) {
                _taxFee = _buyTaxFee;
                _liquidityFee = _buyLiquidityFee + _buyMarketingFee;
                if (_liquidityFee > 0) {
                    buyOrSellSwitch = BUY;
                }
            }
            // Sell
            else if (automatedMarketMakerPairs[to]) {
                _taxFee = _sellTaxFee;
                _liquidityFee = _sellLiquidityFee + _sellMarketingFee;
                if (_liquidityFee > 0) {
                    buyOrSellSwitch = SELL;
                }
            }
        }

        _tokenTransfer(from, to, amount);

        restoreAllFee();
    }

    function swapBack() private lockTheSwap {
        uint256 contractBalance = balanceOf(address(this));
        bool success;
        uint256 totalTokensToSwap = _liquidityTokensToSwap +
            _marketingTokensToSwap;
        if (totalTokensToSwap == 0 || contractBalance == 0) {
            return;
        }

        // Halve the amount of liquidity tokens
        uint256 tokensForLiquidity = ((contractBalance *
            _liquidityTokensToSwap) / totalTokensToSwap) / 2;
        uint256 amountToSwapForBNB = contractBalance.sub(tokensForLiquidity);

        uint256 initialBNBBalance = address(this).balance;

        swapTokensForBNB(amountToSwapForBNB);

        uint256 bnbBalance = address(this).balance.sub(initialBNBBalance);

        uint256 bnbForMarketing = bnbBalance.mul(_marketingTokensToSwap).div(
            totalTokensToSwap
        );

        uint256 bnbForLiquidity = bnbBalance - bnbForMarketing;

        _liquidityTokensToSwap = 0;
        _marketingTokensToSwap = 0;

        if (tokensForLiquidity > 0 && bnbForLiquidity > 0) {
            addLiquidity(tokensForLiquidity, bnbForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForBNB,
                bnbForLiquidity,
                tokensForLiquidity
            );
        }

        (success, ) = address(marketingAddress).call{
            value: address(this).balance
        }("");
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();
        _approve(address(this), address(pancakeRouter), tokenAmount);
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(pancakeRouter), tokenAmount);
        pancakeRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            liquidityAddress,
            block.timestamp
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeLiquidity(tLiquidity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tLiquidity,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tLiquidity
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tLiquidity = calculateLiquidityFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tLiquidity);
        return (tTransferAmount, tFee, tLiquidity);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 currentRate
    )
        private
        pure
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rLiquidity);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function addBots(address[] memory _bots)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _bots.length; i++) {
            bots[_bots[i]] = true;
        }
        emit LogAddBots(_bots);
    }

    function removeBots(address[] memory _notbots)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < _notbots.length; i++) {
            bots[_notbots[i]] = false;
        }
        emit LogRemoveBots(_notbots);
    }

    function _takeLiquidity(uint256 tLiquidity) private {
        if (buyOrSellSwitch == BUY) {
            _liquidityTokensToSwap +=
                (tLiquidity * _buyLiquidityFee) /
                _liquidityFee;
            _marketingTokensToSwap +=
                (tLiquidity * _buyMarketingFee) /
                _liquidityFee;
        } else if (buyOrSellSwitch == SELL) {
            _liquidityTokensToSwap +=
                (tLiquidity * _sellLiquidityFee) /
                _liquidityFee;
            _marketingTokensToSwap +=
                (tLiquidity * _sellMarketingFee) /
                _liquidityFee;
        }
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rLiquidity);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tLiquidity);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**2);
    }

    function removeAllFee() private {
        if (_taxFee == 0 && _liquidityFee == 0) return;

        _previousTaxFee = _taxFee;
        _previousLiquidityFee = _liquidityFee;

        _taxFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _liquidityFee = _previousLiquidityFee;
    }

    function isExcludedFromFee(address account) external view returns (bool) {
        return _isExcludedFromFee[account];
    }

    function excludeFromFee(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _isExcludedFromFee[account] = false;
    }

    function setBuyFee(
        uint256 buyTaxFee,
        uint256 buyLiquidityFee,
        uint256 buyMarketingFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _buyTaxFee = buyTaxFee;
        _buyLiquidityFee = buyLiquidityFee;
        _buyMarketingFee = buyMarketingFee;
        require(
            _buyTaxFee + _buyLiquidityFee + _buyMarketingFee <= 20,
            "Must keep taxes below 20%"
        );
    }

    function setSellFee(
        uint256 sellTaxFee,
        uint256 sellLiquidityFee,
        uint256 sellMarketingFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _sellTaxFee = sellTaxFee;
        _sellLiquidityFee = sellLiquidityFee;
        _sellMarketingFee = sellMarketingFee;
        require(
            _sellTaxFee + _sellLiquidityFee + _sellMarketingFee <= 30,
            "Must keep taxes below 30%"
        );
    }

    function setMarketingAddress(address _marketingAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        marketingAddress = payable(_marketingAddress);
        _isExcludedFromFee[marketingAddress] = true;
    }

    function setLiquidityAddress(address _liquidityAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        liquidityAddress = payable(_liquidityAddress);
        _isExcludedFromFee[liquidityAddress] = true;
    }

    function setSwapAndLiquifyEnabled(bool _enabled)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    // useful for buybacks or to reclaim any BNB on the contract in a way that helps holders.
    function buyBackTokens(uint256 bnbAmountInWei)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // generate the uniswap pair path of weth -> eth
        address[] memory path = new address[](2);
        path[0] = pancakeRouter.WETH();
        path[1] = address(this);

        // make the swap
        pancakeRouter.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: bnbAmountInWei
        }(
            0, // accept any amount of Ethereum
            path,
            address(0xdead),
            block.timestamp
        );
    }

    // To receive ETH from pancakeRouter when swapping
    

    function transferForeignToken(address _token, address _to)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool _sent)
    {
        require(_token != address(this), "Can't withdraw native tokens");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }
    function mint(address account, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _mint(account, amount);
    }
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        uint256 currentRate=_getRate();
        if(_isExcluded[account])
            _tOwned[account]=_tOwned[account].add(amount);
        _rOwned[account]=_rOwned[account].add(amount.mul(currentRate));
        _tTotal=_tTotal.add(amount);
        _rTotal=_rTotal.add(amount.mul(currentRate));
        require(
            _tTotal <= _maxSupply(),
            "ERC20Votes: total supply risks overflowing votes"
        );
    }

    /**
     * @dev Snapshots the totalSupply after it has been decreased.
     */
    function _burn(address account, uint256 amount) internal virtual {
        uint256 currentRate=_getRate();        
        if(_isExcluded[account]){
            require(_tOwned[account]>amount, "insufficient funds");
            _tOwned[account]=_tOwned[account].sub(amount);
        }
        require(_rOwned[account]>amount.mul(currentRate), "insufficient funds");
        _rOwned[account]=_rOwned[account].sub(amount.mul(currentRate));
        _tTotal=_tTotal.sub(amount);
        _rTotal=_rTotal.sub(amount.mul(currentRate));
    }
    function _maxSupply() internal view virtual returns (uint224) {
        return type(uint224).max;
    }
    receive() external payable {}
}
