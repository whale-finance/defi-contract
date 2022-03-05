// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./openzeppelin/SafeMath.sol";
import "./owner/Operator.sol";
import "./interfaces/ITaxable.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";

contract TaxOfficeV2 is Operator {
    using SafeMath for uint256;

    address public main;
    address public uniRouter;
    address public wftm;

    constructor(address _main, address _pair, address _wftm) public {
        require(_main != address(0), "main address cannot be 0");
        require(_pair != address(0), "pair address cannot be 0");
        require(_wftm != address(0), "wftm address cannot be 0");
        main = _main;
        uniRouter = _pair;
        wftm = _wftm;
    }

    mapping(address => bool) public taxExclusionEnabled;

    function setTaxTiersTwap(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(main).setTaxTiersTwap(_index, _value);
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(main).setTaxTiersRate(_index, _value);
    }

    function enableAutoCalculateTax() public onlyOperator {
        ITaxable(main).enableAutoCalculateTax();
    }

    function disableAutoCalculateTax() public onlyOperator {
        ITaxable(main).disableAutoCalculateTax();
    }

    function setTaxRate(uint256 _taxRate) public onlyOperator {
        ITaxable(main).setTaxRate(_taxRate);
    }

    function setBurnThreshold(uint256 _burnThreshold) public onlyOperator {
        ITaxable(main).setBurnThreshold(_burnThreshold);
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyOperator {
        ITaxable(main).setTaxCollectorAddress(_taxCollectorAddress);
    }

    function excludeAddressFromTax(address _address) external onlyOperator returns (bool) {
        return _excludeAddressFromTax(_address);
    }

    function _excludeAddressFromTax(address _address) private returns (bool) {
        if (!ITaxable(main).isAddressExcluded(_address)) {
            return ITaxable(main).excludeAddress(_address);
        }
    }

    function includeAddressInTax(address _address) external onlyOperator returns (bool) {
        return _includeAddressInTax(_address);
    }

    function _includeAddressInTax(address _address) private returns (bool) {
        if (ITaxable(main).isAddressExcluded(_address)) {
            return ITaxable(main).includeAddress(_address);
        }
    }

    function taxRate() external view returns (uint256) {
        return ITaxable(main).taxRate();
    }

    function addLiquidityTaxFree(
        address token,
        uint256 amtMain,
        uint256 amtToken,
        uint256 amtMainMin,
        uint256 amtTokenMin
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtMain != 0 && amtToken != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(main).transferFrom(msg.sender, address(this), amtMain);
        IERC20(token).transferFrom(msg.sender, address(this), amtToken);
        _approveTokenIfNeeded(main, uniRouter);
        _approveTokenIfNeeded(token, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtMain;
        uint256 resultAmtToken;
        uint256 liquidity;
        (resultAmtMain, resultAmtToken, liquidity) = IUniswapV2Router(uniRouter).addLiquidity(
            main,
            token,
            amtMain,
            amtToken,
            amtMainMin,
            amtTokenMin,
            msg.sender,
            block.timestamp
        );

        if(amtMain.sub(resultAmtMain) > 0) {
            IERC20(main).transfer(msg.sender, amtMain.sub(resultAmtMain));
        }
        if(amtToken.sub(resultAmtToken) > 0) {
            IERC20(token).transfer(msg.sender, amtToken.sub(resultAmtToken));
        }
        return (resultAmtMain, resultAmtToken, liquidity);
    }

    function addLiquidityETHTaxFree(
        uint256 amtMain,
        uint256 amtMainMin,
        uint256 amtFtmMin
    )
        external
        payable
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtMain != 0 && msg.value != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(main).transferFrom(msg.sender, address(this), amtMain);
        _approveTokenIfNeeded(main, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtMain;
        uint256 resultAmtFtm;
        uint256 liquidity;
        (resultAmtMain, resultAmtFtm, liquidity) = IUniswapV2Router(uniRouter).addLiquidityETH{value: msg.value}(
            main,
            amtMain,
            amtMainMin,
            amtFtmMin,
            msg.sender,
            block.timestamp
        );

        if(amtMain.sub(resultAmtMain) > 0) {
            IERC20(main).transfer(msg.sender, amtMain.sub(resultAmtMain));
        }
        return (resultAmtMain, resultAmtFtm, liquidity);
    }

    function setTaxableMainOracle(address _mainOracle) external onlyOperator {
        ITaxable(main).setMainOracle(_mainOracle);
    }

    function transferTaxOffice(address _newTaxOffice) external onlyOperator {
        ITaxable(main).setTaxOffice(_newTaxOffice);
    }

    function taxFreeTransferFrom(
        address _sender,
        address _recipient,
        uint256 _amt
    ) external {
        require(taxExclusionEnabled[msg.sender], "Address not approved for tax free transfers");
        _excludeAddressFromTax(_sender);
        IERC20(main).transferFrom(_sender, _recipient, _amt);
        _includeAddressInTax(_sender);
    }

    function setTaxExclusionForAddress(address _address, bool _excluded) external onlyOperator {
        taxExclusionEnabled[_address] = _excluded;
    }

    function _approveTokenIfNeeded(address _token, address _router) private {
        if (IERC20(_token).allowance(address(this), _router) == 0) {
            IERC20(_token).approve(_router, type(uint256).max);
        }
    }
}
