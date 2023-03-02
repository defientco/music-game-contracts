// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Vm} from "forge-std/Vm.sol";
import {DSTest} from "ds-test/test.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";

import {IERC721Drop} from "../src/interfaces/IERC721Drop.sol";
import {ERC721MusicGame} from "../src/ERC721MusicGame.sol";
import {DummyMetadataRenderer} from "./utils/DummyMetadataRenderer.sol";
import {MusicGameMetadataRenderer} from "../src/metadata/MusicGameMetadataRenderer.sol";
import {MockUser} from "./utils/MockUser.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {ERC721DropProxy} from "../src/ERC721DropProxy.sol";
import {ChillToken} from "../src/utils/ChillToken.sol";

contract ERC721MusicGameTest is DSTest {
    /// @notice Event emitted when the funds are withdrawn from the minting contract
    /// @param withdrawnBy address that issued the withdraw
    /// @param withdrawnTo address that the funds were withdrawn to
    /// @param amount amount that was withdrawn
    event FundsWithdrawn(
        address indexed withdrawnBy,
        address indexed withdrawnTo,
        uint256 amount
    );

    ERC721MusicGame musicGame;
    ChillToken ct;
    MockUser mockUser;
    uint256[] samples;
    Vm public constant vm = Vm(HEVM_ADDRESS);
    DummyMetadataRenderer public dummyRenderer = new DummyMetadataRenderer();
    MusicGameMetadataRenderer public musicGameRenderer =
        new MusicGameMetadataRenderer();
    FactoryUpgradeGate public factoryUpgradeGate;
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    address public constant UPGRADE_GATE_ADMIN_ADDRESS = address(0x942924224);
    address public constant mediaContract = address(0x123456);
    address public impl;

    struct Configuration {
        IMetadataRenderer metadataRenderer;
        uint64 editionSize;
        uint16 royaltyBPS;
        address payable fundsRecipient;
    }

    modifier setupZoraNFTBase(uint64 editionSize) {
        _;
    }

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        factoryUpgradeGate = new FactoryUpgradeGate(UPGRADE_GATE_ADMIN_ADDRESS);
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        impl = address(
            new ERC721MusicGame({
                _contractName: "Test NFT",
                _contractSymbol: "TNFT",
                _initialOwner: DEFAULT_OWNER_ADDRESS,
                _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
                _editionSize: type(uint64).max,
                _royaltyBPS: 800,
                _metadataRenderer: dummyRenderer,
                _salesConfig: IERC721Drop.ERC20SalesConfiguration({
                    publicSaleStart: 0,
                    erc20PaymentToken: address(0),
                    publicSaleEnd: 0,
                    presaleStart: 0,
                    presaleEnd: 0,
                    publicSalePrice: 0,
                    maxSalePurchasePerAddress: 0,
                    presaleMerkleRoot: bytes32(0)
                })
            })
        );
        musicGame = new ERC721MusicGame({
            _contractName: "Test NFT",
            _contractSymbol: "TNFT",
            _initialOwner: DEFAULT_OWNER_ADDRESS,
            _fundsRecipient: payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            _editionSize: type(uint64).max,
            _royaltyBPS: 800,
            _metadataRenderer: musicGameRenderer,
            _salesConfig: IERC721Drop.ERC20SalesConfiguration({
                publicSaleStart: 0,
                erc20PaymentToken: address(0),
                publicSaleEnd: 0,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            })
        });
        ct = new ChillToken(address(1));
        samples.push(1);
        vm.prank(address(1));
        ct.mint(address(1), type(uint64).max);
    }

    function test_Init() public setupZoraNFTBase(10) {
        require(
            musicGame.owner() == DEFAULT_OWNER_ADDRESS,
            "Default owner set wrong"
        );

        (
            IMetadataRenderer renderer,
            uint64 editionSize,
            uint16 royaltyBPS,
            address payable fundsRecipient
        ) = musicGame.config();

        require(
            address(renderer) == address(musicGameRenderer),
            "incorrect metadata renderer"
        );
        require(editionSize == type(uint64).max, "EditionSize is wrong");
        require(royaltyBPS == 800, "RoyaltyBPS is wrong");
        require(
            fundsRecipient == payable(DEFAULT_FUNDS_RECIPIENT_ADDRESS),
            "FundsRecipient is wrong"
        );

        string memory name = musicGame.name();
        string memory symbol = musicGame.symbol();
        require(keccak256(bytes(name)) == keccak256(bytes("Test NFT")));
        require(keccak256(bytes(symbol)) == keccak256(bytes("TNFT")));
    }

    function test_Purchase(uint64 amount) public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: amount,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        vm.deal(address(456), uint256(amount) * 2);
        vm.prank(address(456));

        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );

        musicGame.purchase{value: amount}(1, initData);

        assertEq(musicGame.saleDetails().maxSupply, type(uint64).max);
        assertEq(musicGame.saleDetails().totalMinted, 1);
        assertEq(musicGame.saleDetails().erc20PaymentToken, address(0));
        require(
            musicGame.ownerOf(1) == address(456),
            "owner is wrong for new minted token"
        );
        assertEq(address(musicGame).balance, amount);
    }

    function test_Purchase_setsMetadata(uint64 amount)
        public
        setupZoraNFTBase(10)
    {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: amount,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setMetadataRenderer(musicGameRenderer, "");
        assertEq(
            address(musicGame.metadataRenderer()),
            address(musicGameRenderer)
        );

        vm.deal(address(456), uint256(amount) * 2);
        vm.prank(address(456));

        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "Description for metadata",
            "https://example.com/image.png",
            "https://example.com/animation.mp4",
            initSamples
        );

        musicGame.purchase{value: amount}(1, initData);

        MusicGameMetadataRenderer.TokenEditionInfo
            memory info = musicGameRenderer.tokenInfos(address(musicGame), 1);
        assertEq(info.description, "Description for metadata");
        assertEq(info.animationURI, "https://example.com/animation.mp4");
        assertEq(info.imageURI, "https://example.com/image.png");

        initData = abi.encode(
            "Description for metadata2",
            "https://example.com/image2.png",
            "https://example.com/animation2.mp4",
            samples
        );

        musicGame.purchase{value: amount}(1, initData);

        info = musicGameRenderer.tokenInfos(address(musicGame), 2);
        assertEq(info.description, "Description for metadata2");
        assertEq(info.animationURI, "https://example.com/animation2.mp4");
        assertEq(info.imageURI, "https://example.com/image2.png");
    }

    function test_PurchaseERC20_Revert_InsufficientAllowance(uint64 amount)
        public
        setupZoraNFTBase(10)
    {
        assertEq(ct.minter(), address(1));
        assertEq(ct.balanceOf(address(1)), type(uint64).max);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(ct),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: amount,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        vm.deal(address(456), uint256(amount) * 2);
        vm.prank(address(456));
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        if (amount > 0) {
            vm.expectRevert("ERC20: insufficient allowance");
            musicGame.purchase(1, initData);
        } else {
            musicGame.purchase(1, initData);
            require(
                musicGame.ownerOf(1) == address(456),
                "owner is wrong for new minted token"
            );
            assertEq(musicGame.saleDetails().totalMinted, 1);
        }
        assertEq(musicGame.saleDetails().maxSupply, type(uint64).max);
        assertEq(musicGame.saleDetails().erc20PaymentToken, address(ct));
    }

    function test_PurchaseERC20(uint64 amount) public setupZoraNFTBase(10) {
        assertEq(ct.minter(), address(1));
        assertEq(ct.balanceOf(address(1)), type(uint64).max);
        assertEq(ct.balanceOf(address(DEFAULT_FUNDS_RECIPIENT_ADDRESS)), 0);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(ct),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: amount,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        vm.prank(address(1));
        ct.approve(address(musicGame), type(uint256).max);
        vm.prank(address(1));

        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        musicGame.purchase(1, initData);
        require(
            musicGame.ownerOf(1) == address(1),
            "owner is wrong for new minted token"
        );
        assertEq(musicGame.saleDetails().totalMinted, 1);
        assertEq(musicGame.saleDetails().maxSupply, type(uint64).max);
        assertEq(musicGame.saleDetails().erc20PaymentToken, address(ct));
        assertEq(ct.balanceOf(address(1)), type(uint64).max - amount);
        assertEq(
            ct.balanceOf(address(DEFAULT_FUNDS_RECIPIENT_ADDRESS)),
            amount
        );
    }

    function test_PurchaseTime() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: 0,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        assertTrue(!musicGame.saleDetails().publicSaleActive);

        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );

        vm.deal(address(456), 1 ether);
        vm.prank(address(456));
        vm.expectRevert(IERC721Drop.Sale_Inactive.selector);
        musicGame.purchase{value: 0.1 ether}(1, initData);

        assertEq(musicGame.saleDetails().maxSupply, type(uint64).max);
        assertEq(musicGame.saleDetails().totalMinted, 0);

        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 9 * 3600,
            publicSaleEnd: 11 * 3600,
            presaleStart: 0,
            presaleEnd: 0,
            maxSalePurchasePerAddress: 20,
            publicSalePrice: 0.1 ether,
            presaleMerkleRoot: bytes32(0)
        });

        assertTrue(!musicGame.saleDetails().publicSaleActive);
        // jan 1st 1980
        vm.warp(10 * 3600);
        assertTrue(musicGame.saleDetails().publicSaleActive);
        assertTrue(!musicGame.saleDetails().presaleActive);

        vm.prank(address(456));
        musicGame.purchase{value: 0.1 ether}(1, initData);

        assertEq(musicGame.saleDetails().totalMinted, 1);
        assertEq(musicGame.ownerOf(1), address(456));
    }

    function test_Mint() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        assertEq(musicGame.saleDetails().maxSupply, type(uint64).max);
        assertEq(musicGame.saleDetails().totalMinted, 1);
        require(
            musicGame.ownerOf(1) == DEFAULT_OWNER_ADDRESS,
            "Owner is wrong for new minted token"
        );
    }

    function test_MintWrongValue() public setupZoraNFTBase(10) {
        vm.deal(address(456), 1 ether);
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        vm.prank(address(456));
        vm.expectRevert(IERC721Drop.Sale_Inactive.selector);
        musicGame.purchase{value: 0.12 ether}(1, initData);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.15 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });
        vm.prank(address(456));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC721Drop.Purchase_WrongPrice.selector,
                0.15 ether
            )
        );
        musicGame.purchase{value: 0.12 ether}(1, initData);
    }

    function test_Withdraw(uint128 amount) public setupZoraNFTBase(10) {
        vm.assume(amount > 0.01 ether);
        vm.deal(address(musicGame), amount);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        vm.expectEmit(true, true, true, true);
        uint256 leftoverFunds = amount;
        emit FundsWithdrawn(
            DEFAULT_OWNER_ADDRESS,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            leftoverFunds
        );
        musicGame.withdraw();

        assertTrue(
            DEFAULT_ZORA_DAO_ADDRESS.balance <
                ((uint256(amount) * 1_000 * 5) / 100000) + 2 ||
                DEFAULT_ZORA_DAO_ADDRESS.balance >
                ((uint256(amount) * 1_000 * 5) / 100000) + 2
        );
        assertTrue(
            DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance >
                ((uint256(amount) * 1_000 * 95) / 100000) - 2 ||
                DEFAULT_FUNDS_RECIPIENT_ADDRESS.balance <
                ((uint256(amount) * 1_000 * 95) / 100000) + 2
        );
    }

    function testSetSalesConfiguration() public setupZoraNFTBase(10) {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 100,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 10,
            presaleMerkleRoot: bytes32(0)
        });

        (, , , , , , uint64 presaleEndLookup, ) = musicGame.salesConfig();
        assertEq(presaleEndLookup, 100);

        address SALES_MANAGER_ADDR = address(0x11002);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        musicGame.grantRole(musicGame.SALES_MANAGER_ROLE(), SALES_MANAGER_ADDR);
        vm.stopPrank();
        vm.prank(SALES_MANAGER_ADDR);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 100,
            presaleEnd: 0,
            publicSalePrice: 0.1 ether,
            maxSalePurchasePerAddress: 1003,
            presaleMerkleRoot: bytes32(0)
        });

        (
            ,
            ,
            ,
            ,
            ,
            uint64 presaleStartLookup2,
            uint64 presaleEndLookup2,

        ) = musicGame.salesConfig();
        assertEq(presaleEndLookup2, 0);
        assertEq(presaleStartLookup2, 100);
    }

    function test_WithdrawNotAllowed() public setupZoraNFTBase(10) {
        vm.expectRevert(IERC721Drop.Access_WithdrawNotAllowed.selector);
        musicGame.withdraw();
    }

    function test_ValidFinalizeOpenEdition()
        public
        setupZoraNFTBase(type(uint64).max)
    {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.2 ether,
            presaleMerkleRoot: bytes32(0),
            maxSalePurchasePerAddress: 10
        });
        uint256[] memory initSamples = new uint256[](0);
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        musicGame.purchase{value: 0.6 ether}(3, initData);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.adminMint(address(0x1234), 2);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.finalizeOpenEdition();
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.adminMint(address(0x1234), 2);
        vm.expectRevert(IERC721Drop.Mint_SoldOut.selector);
        musicGame.purchase{value: 0.6 ether}(3, initData);
    }

    function test_BYTES_BYTES_BYTES()
        public
        setupZoraNFTBase(type(uint64).max)
    {
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.2 ether,
            presaleMerkleRoot: bytes32(0),
            maxSalePurchasePerAddress: 10
        });
        bytes memory initData = abi.encode(
            "Music Game by CRE8ORS",
            "ipfs://bafybeie4aujrsejizhllu62bzpc7ptiulnncsa4eqizd2ogea457io7lym/mickey mouse as a chef cutting mushrooms in the kithcen.png?",
            "ipfs://bafybeigweadrkf2rcy3kjgtvn6ixedpbcwkll2uek6pl4ub7zfzfpxutxy/6.mp3?id=0"
        );
        emit log_bytes(initData);
    }

    function test_AdminMint() public setupZoraNFTBase(10) {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        musicGame.adminMint(DEFAULT_OWNER_ADDRESS, 1);
        require(
            musicGame.balanceOf(DEFAULT_OWNER_ADDRESS) == 1,
            "Wrong balance"
        );
        musicGame.grantRole(musicGame.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.prank(minter);
        musicGame.adminMint(minter, 1);
        require(musicGame.balanceOf(minter) == 1, "Wrong balance");
        assertEq(musicGame.saleDetails().totalMinted, 2);
    }

    // test Admin airdrop
    function test_AdminMintAirdrop() public setupZoraNFTBase(1000) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        address[] memory toMint = new address[](4);
        toMint[0] = address(0x10);
        toMint[1] = address(0x11);
        toMint[2] = address(0x12);
        toMint[3] = address(0x13);
        musicGame.adminMintAirdrop(toMint);
        assertEq(musicGame.saleDetails().totalMinted, 4);
        assertEq(musicGame.balanceOf(address(0x10)), 1);
        assertEq(musicGame.balanceOf(address(0x11)), 1);
        assertEq(musicGame.balanceOf(address(0x12)), 1);
        assertEq(musicGame.balanceOf(address(0x13)), 1);
    }

    function test_AdminMintAirdropFails() public setupZoraNFTBase(1000) {
        vm.startPrank(address(0x10));
        address[] memory toMint = new address[](4);
        toMint[0] = address(0x10);
        toMint[1] = address(0x11);
        toMint[2] = address(0x12);
        toMint[3] = address(0x13);
        bytes32 minterRole = musicGame.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature(
                "AdminAccess_MissingRoleOrAdmin(bytes32)",
                minterRole
            )
        );
        musicGame.adminMintAirdrop(toMint);
    }

    // test admin mint non-admin permissions
    function test_AdminMintBatch() public setupZoraNFTBase(1000) {
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        musicGame.adminMint(DEFAULT_OWNER_ADDRESS, 100);
        assertEq(musicGame.saleDetails().totalMinted, 100);
        assertEq(musicGame.balanceOf(DEFAULT_OWNER_ADDRESS), 100);
    }

    function test_AdminMintBatchFails() public setupZoraNFTBase(1000) {
        vm.startPrank(address(0x10));
        bytes32 role = musicGame.MINTER_ROLE();
        vm.expectRevert(
            abi.encodeWithSignature(
                "AdminAccess_MissingRoleOrAdmin(bytes32)",
                role
            )
        );
        musicGame.adminMint(address(0x10), 100);
    }

    function test_Burn() public setupZoraNFTBase(10) {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        musicGame.grantRole(musicGame.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        address[] memory airdrop = new address[](1);
        airdrop[0] = minter;
        musicGame.adminMintAirdrop(airdrop);
        musicGame.burn(1);
        vm.stopPrank();
    }

    function test_BurnNonOwner() public setupZoraNFTBase(10) {
        address minter = address(0x32402);
        vm.startPrank(DEFAULT_OWNER_ADDRESS);
        musicGame.grantRole(musicGame.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        address[] memory airdrop = new address[](1);
        airdrop[0] = minter;
        musicGame.adminMintAirdrop(airdrop);
        vm.stopPrank();

        vm.prank(address(1));
        vm.expectRevert(
            IERC721AUpgradeable.TransferCallerNotOwnerNorApproved.selector
        );
        musicGame.burn(1);
    }

    // Add test burn failure state for users that don't own the token
    function test_EIP165() public view {
        require(musicGame.supportsInterface(0x01ffc9a7), "supports 165");
        // TODO: get these passing with non-upgradeable interface
        // require(musicGame.supportsInterface(0x80ac58cd), "supports 721");
        // require(
        //     musicGame.supportsInterface(0x5b5e139f),
        //     "supports 721-metdata"
        // );
        require(musicGame.supportsInterface(0x2a55205a), "supports 2981");
        require(
            !musicGame.supportsInterface(0x0000000),
            "doesnt allow non-interface"
        );
    }

    function test_cre8ingTokens() public {
        vm.deal(address(456), 1 ether);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0.01 ether,
            maxSalePurchasePerAddress: 2,
            presaleMerkleRoot: bytes32(0)
        });

        uint256[] memory initSamples = new uint256[](0);
        // metadata for new mix
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            initSamples
        );
        vm.stopPrank();
        vm.startPrank(address(0x14));
        vm.deal(address(0x14), 1 ether);
        musicGame.purchase{value: 0.01 ether}(1, initData);

        // verify airdrop for sample holders
        assertEq(musicGame.saleDetails().totalMinted, 9);
        assertEq(musicGame.balanceOf(address(0x10)), 2);
        assertEq(musicGame.balanceOf(address(0x11)), 2);
        assertEq(musicGame.balanceOf(address(0x12)), 2);
        assertEq(musicGame.balanceOf(address(0x13)), 2);
        assertEq(musicGame.balanceOf(address(0x14)), 1);

        uint256[] memory newSamples = new uint256[](4);
        newSamples[0] = 1;
        newSamples[1] = 2;
        newSamples[2] = 3;
        newSamples[3] = 4;
        initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/",
            newSamples
        );
        musicGame.purchase{value: 0.01 ether}(1, initData);
        uint256[] memory staked = musicGame.cre8ingTokens();
        assertEq(staked.length, 100);
        for (uint256 i = 0; i < staked.length; i++) {
            assertEq(staked[i], 0);
        }
        uint256[] memory unstaked = new uint256[](100);
        for (uint256 i = 0; i < unstaked.length; i++) {
            unstaked[i] = i + 1;
        }
        vm.stopPrank();
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setCre8ingOpen(true);
        vm.startPrank(address(0x14));
        musicGame.toggleCre8ing(unstaked);
        staked = musicGame.cre8ingTokens();
        for (uint256 i = 0; i < staked.length; i++) {
            assertEq(staked[i], i + 1);
        }
        assertEq(staked.length, 100);
    }

    function test_cre8ingURI() public {
        vm.deal(address(456), 1 ether);
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setSaleConfiguration({
            erc20PaymentToken: address(0),
            publicSaleStart: 0,
            publicSaleEnd: type(uint64).max,
            presaleStart: 0,
            presaleEnd: 0,
            publicSalePrice: 0,
            maxSalePurchasePerAddress: 0,
            presaleMerkleRoot: bytes32(0)
        });
        bytes memory initData = abi.encode(
            "",
            "http://imgUri/",
            "http://animationUri/"
        );
        musicGame.purchase(100, initData);
        string[] memory staked = musicGame.cre8ingURI();
        assertEq(staked.length, 100);
        for (uint256 i = 0; i < staked.length; i++) {
            assertEq(staked[i], "");
        }
        uint256[] memory unstaked = new uint256[](100);
        for (uint256 i = 0; i < unstaked.length; i++) {
            unstaked[i] = i + 1;
        }
        vm.prank(DEFAULT_OWNER_ADDRESS);
        musicGame.setCre8ingOpen(true);
        musicGame.toggleCre8ing(unstaked);
        staked = musicGame.cre8ingURI();
        for (uint256 i = 0; i < staked.length; i++) {
            assertEq(staked[i], musicGame.tokenURI(i + 1));
        }
        assertEq(staked.length, 100);
    }
}

// // test Music Game Init
//     function test_MusicGameAirdrop() public setupZoraNFTBase(1000) {
//         vm.startPrank(DEFAULT_OWNER_ADDRESS);

//         // airdrop initial game samples
//         address[] memory toMint = new address[](4);
//         toMint[0] = address(0x10);
//         toMint[1] = address(0x11);
//         toMint[2] = address(0x12);
//         toMint[3] = address(0x13);
//         zoraNFTBase.adminMintAirdrop(toMint);
//         assertEq(zoraNFTBase.saleDetails().totalMinted, 4);
//         assertEq(zoraNFTBase.balanceOf(address(0x10)), 1);
//         assertEq(zoraNFTBase.balanceOf(address(0x11)), 1);
//         assertEq(zoraNFTBase.balanceOf(address(0x12)), 1);
//         assertEq(zoraNFTBase.balanceOf(address(0x13)), 1);

//         // prepare game
//         zoraNFTBase.setSaleConfiguration({
