// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
    }

    function _deposit(address user, uint256 amount) internal {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amount);
        dsce.depositCollateral(weth, amount);
        vm.stopPrank();
    }

    function _mintDsc(address user, uint256 amount) internal {
        vm.startPrank(user);
        dsce.mintDsc(amount);
        vm.stopPrank();
    }

    function _makeUserUnhealthy(address user) internal {
        // Price drop: 2000e8 -> 1000e8 (half), breaks health factor if user minted near threshold
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1000e8);
    }

    ////////////////////////////
    ////  Constructor Tests ////
    ////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    ////////////////////////
    //     Price Tests    //
    ////////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        // $2000 / ETH, $100
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    //////////////////////////////
    // Deposit Collateral Tests //
    //////////////////////////////

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testDepositCollateralAndMintDscWorks() public {
        uint256 depositAmt = 10 ether;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), depositAmt);

        // Calculate safe mint (<= 50% of collateral value)
        uint256 collateralValueInUsd = dsce.getUsdValue(weth, depositAmt);
        uint256 safeMint = collateralValueInUsd / 2 - 1e18;

        dsce.depositCollateralAndMintDsc(weth, depositAmt, safeMint);
        vm.stopPrank();

        (uint256 minted, uint256 collateralValueInUsdAfter) = dsce.getAccountInformation(USER);
        assertEq(minted, safeMint);
        assertEq(collateralValueInUsdAfter, collateralValueInUsd);
        assertEq(dsc.balanceOf(USER), safeMint);
    }

    function testDepositCollateralAndMintDscRevertsOnZeroMint() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), 5 ether);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateralAndMintDsc(weth, 5 ether, 0);
        vm.stopPrank();
    }

    function testMintDscWorks() public {
        uint256 depositAmt = 10 ether;
        _deposit(USER, depositAmt);

        uint256 collateralValueInUsd = dsce.getUsdValue(weth, depositAmt);
        uint256 safeMint = collateralValueInUsd / 2 - 1e18;

        vm.startPrank(USER);
        dsce.mintDsc(safeMint);
        vm.stopPrank();

        (uint256 minted,) = dsce.getAccountInformation(USER);
        assertEq(minted, safeMint);
        assertEq(dsc.balanceOf(USER), safeMint);
    }

    function testMintDscRevertsWithoutCollateral() public {
        vm.startPrank(USER);
        // Even 1e18 should revert (health factor < 1 because collateral = 0)
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dsce.mintDsc(1e18);
        vm.stopPrank();
    }

    function testRedeemCollateralWorks() public {
        uint256 depositAmt = 10 ether;
        _deposit(USER, depositAmt);

        uint256 collatUsd = dsce.getUsdValue(weth, depositAmt);
        uint256 mintAmt = collatUsd / 4; // safe
        _mintDsc(USER, mintAmt);

        uint256 redeemAmt = 3 ether;
        uint256 before = ERC20Mock(weth).balanceOf(USER);

        vm.startPrank(USER);
        dsce.redeemCollateral(weth, redeemAmt);
        vm.stopPrank();

        uint256 afterBal = ERC20Mock(weth).balanceOf(USER);
        assertEq(afterBal, before + redeemAmt);
    }

    function testRedeemCollateralRevertsOnZero() public {
        _deposit(USER, 5 ether);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRedeemCollateralForDscHappy() public {
        uint256 depositAmt = 10 ether;
        _deposit(USER, depositAmt);

        uint256 collatUsd = dsce.getUsdValue(weth, depositAmt);
        uint256 mintAmt = collatUsd / 3;
        _mintDsc(USER, mintAmt);

        // Burn some DSC & redeem some collateral
        uint256 burnAmt = mintAmt / 2;
        uint256 redeemAmt = 2 ether;

        vm.startPrank(USER);
        // burnDsc inside needs transferFrom, so approve Engine:
        dsc.approve(address(dsce), burnAmt);
        dsce.redeemCollateralForDsc(weth, redeemAmt, burnAmt);
        vm.stopPrank();

        // Checks
        assertEq(dsc.balanceOf(USER), mintAmt - burnAmt);
        assertEq(ERC20Mock(weth).balanceOf(USER), redeemAmt); // since user started with 0 WETH in wallet in test; adjust if needed
    }

    function testBurnDscHappy() public {
        _deposit(USER, 10 ether);
        uint256 mintAmt = dsce.getUsdValue(weth, 10 ether) / 4;
        _mintDsc(USER, mintAmt);

        vm.startPrank(USER);
        dsc.approve(address(dsce), mintAmt);
        dsce.burnDsc(mintAmt / 2);
        vm.stopPrank();

        (uint256 mintedAfter,) = dsce.getAccountInformation(USER);
        assertEq(mintedAfter, mintAmt - mintAmt / 2);
    }

    function testBurnDscRevertsOnZero() public {
        _deposit(USER, 5 ether);
        _mintDsc(USER, 1000e18);

        vm.startPrank(USER);
        dsc.approve(address(dsce), type(uint256).max);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.burnDsc(0);
        vm.stopPrank();
    }

    function testLiquidateRevertsIfHealthFactorOk() public {
        // USER: deposit + safe mint
        _deposit(USER, 10 ether);
        uint256 mintAmt = dsce.getUsdValue(weth, 10 ether) / 4;
        _mintDsc(USER, mintAmt);

        // LIQUIDATOR: kuch DSC le aata hai (apne deposit se)
        _deposit(LIQUIDATOR, 10 ether);
        _mintDsc(LIQUIDATOR, 1000e18);

        vm.startPrank(LIQUIDATOR);
        dsc.approve(address(dsce), type(uint256).max);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dsce.liquidate(weth, USER, 100e18);
        vm.stopPrank();
    }

    function testGetters() public {
        assertEq(dsce.getPrecision(), 1e18);
        assertEq(dsce.getAdditionalFeedPrecision(), 1e10);
        assertEq(dsce.getLiquidationThreshold(), 50);
        assertEq(dsce.getLiquidationPrecision(), 100);
        assertEq(dsce.getLiquidationBonus(), 10);
        assertEq(dsce.getMinHealthFactor(), 1e18);
        assertEq(dsce.getDsc(), address(dsc));
        assertEq(dsce.getCollateralTokenPriceFeed(weth), ethUsdPriceFeed);

        address[] memory toks = dsce.getCollateralTokens();
        assertEq(toks.length, 2); // weth & wbtc as per your DeployDSC
    }

    function testHealthFactorAtBoundary() public {
        _deposit(USER, 10 ether);
        uint256 collatUsd = dsce.getUsdValue(weth, 10 ether);
        uint256 maxMint = collatUsd / 2; // exactly threshold

        // Mint almost max (but not more)
        _mintDsc(USER, maxMint - 1);

        uint256 hf = dsce.getHealthFactor(USER);
        assertGe(hf, 1e18);
    }
}
