const { ethers } = require("hardhat")
const { expect } = require("chai")
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers")
const IERC20 = require("D:/CryptoOrder/artifacts/@uniswap/v2-core/contracts/interfaces/IERC20.sol/IERC20.json")
const routerArtifact = require("../artifacts/@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol/ISwapRouter.json")
const WETH9 = require("../WETH9.json")

const CONTRACT_ADDRESS = {
    WETH:"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    USDT:"0xdAC17F958D2ee523a2206206994597C13D831ec7",
    ROUTER:"0xE592427A0AEce92De3Edee1F18E0157C05861564",
    FACTORY:"0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
}

function getContractInstance(address, artifact, signer) {
  return new hre.ethers.Contract(address, artifact.abi, signer);
}

async function deploy(){
    const [owner1, owner2, owner3, customer] = await ethers.getSigners();
    
    const contracts = {
        weth: getContractInstance(CONTRACT_ADDRESS.WETH ,WETH9, customer),
        usdt: getContractInstance(CONTRACT_ADDRESS.USDT ,IERC20, customer)
    }

    const Factory = await ethers.getContractFactory("CryptoOrderExchange")
    const Exchange = await Factory.deploy(
        [owner1, owner2, owner3],
        [CONTRACT_ADDRESS.USDT, CONTRACT_ADDRESS.WETH],
        ["ETH"],
        "ETH",
        CONTRACT_ADDRESS.USDT,
        CONTRACT_ADDRESS.WETH,
        CONTRACT_ADDRESS.FACTORY,
        CONTRACT_ADDRESS.ROUTER,
        1,
        100
    )
    await Exchange.waitForDeployment()

    const provider = ethers.provider

    
    return { owner1, owner2, owner3, customer, Exchange, contracts}
}

describe("COEX", function () {
	it("DEPLOYS", async () => {
		const { owner1, owner2, owner3, customer, Exchange} = await loadFixture(deploy)

        expect(Exchange.target).to.be.properAddress
	});

    it("CALLS VOTEING & ASSEPTS THE DESIDIONS CORRECTLY", async () => {
        const { owner1, owner2, owner3, customer, Exchange} = await loadFixture(deploy)

        await expect(Exchange.callVoteing([owner1])).to.be.revertedWith('THERE ARE NOT ENOUGHT OWNERS TO ACCEPT DESIDION')
        await Exchange.callVoteing([owner1, owner2])
        await expect(Exchange.connect(owner3).vote(1, true)).to.be.revertedWith('YOU AREN`T INVITED TO THIS VOTE!')
        await expect(Exchange.connect(customer).vote(1, true)).to.be.revertedWith('YOU AREN`T OWNER!')

        await expect(Exchange.connect(owner1).vote(1,false)).to.be.revertedWith('YOU ALREADY VOTED!')

        await Exchange.connect(owner2).vote(1,true)
        
        let statusChanged = await Exchange.changeOvnerStatus(owner3.address, 1, false)
        let timestamp = (await ethers.provider.getBlock(Exchange.blockNumber)).timestamp

        await expect(statusChanged).to.emit(Exchange, 'OwnerStatusChanged').withArgs(
            owner3.address,
            1,
            2,
            false,
            timestamp
        )

        await expect(Exchange.changeOvnerStatus(owner3.address, 1, false)).to.be.revertedWith('CURRENT VOTEING WAS REJECTED OR OUTDATED!')

        await expect(Exchange.changeOvnerStatus(owner3.address, 2, false)).to.be.rejectedWith('CURRENT VOTEING DOESN`T ALREDY EXIST!')

        await Exchange.callVoteing([owner1, owner2])
        await Exchange.connect(owner2).vote(2,true)

        statusChanged = await Exchange.changeOvnerStatus(owner3.address, 2, true)
        timestamp = (await ethers.provider.getBlock(Exchange.blockNumber)).timestamp

        await expect(statusChanged).to.emit(Exchange, 'OwnerStatusChanged').withArgs(
            owner3.address,
            2,
            3,
            true,
            timestamp
        )

        await Exchange.callVoteing([owner1, owner2, owner3])
        await Exchange.connect(owner2).vote(3, false)
        await expect(Exchange.connect(owner3).vote(3, true)).to.be.revertedWith('CURRENT VOTEING WAS REJECTED OR OUTDATED!')
    });

    it("SEND, SWAP & RESIEVE TOKENS CORECTLY", async () => {
        const { owner1, owner2, owner3, customer, Exchange, contracts } = await loadFixture(deploy)

        let wethBalance = await contracts.weth.balanceOf(customer.address)
        let USDTBalance

        const tx = await contracts.weth.deposit({value: ethers.parseEther('20')})
        await tx.wait()

        wethBalance = await contracts.weth.balanceOf(customer.address)

        let approve = await contracts.weth.approve(Exchange.target,  ethers.parseEther('5'))
        await approve.wait()

        let transferVolume = await Exchange.connect(customer).custommerSwap(CONTRACT_ADDRESS.WETH, CONTRACT_ADDRESS.USDT, ethers.parseEther('5'))
        let logs = await transferVolume.wait()
        let currentFee = logs.logs[1].args[5]
        console.log("Current fee: " + currentFee)

        approve = await contracts.weth.approve(Exchange.target,  ethers.parseEther('5'))
        await approve.wait()

        transferVolume = await Exchange.connect(customer).custommerSwap(CONTRACT_ADDRESS.WETH, CONTRACT_ADDRESS.USDT, ethers.parseEther('5'))
        logs = await transferVolume.wait()
        let currentFee1 = logs.logs[1].args[5]
        console.log("Current fee: " + currentFee1)

        // wethBalance = await contracts.weth.balanceOf(customer.address)
        //await expect(wethBalance).to.be.eq(ethers.parseEther('0'))
        wethBalance = await contracts.weth.balanceOf(Exchange.target)

        await Exchange.callVoteing([owner1, owner2, owner3])
        await Exchange.connect(owner2).vote(1, true)
        await Exchange.connect(owner3).vote(1, true)

        await Exchange.globalSwap(CONTRACT_ADDRESS.WETH, CONTRACT_ADDRESS.USDT, wethBalance, 1)
        wethBalance = await contracts.weth.balanceOf(Exchange.target)
        USDTBalance = await contracts.usdt.balanceOf(Exchange.target)

        approve = await contracts.weth.approve(Exchange.target,  ethers.parseEther('5'))
        await approve.wait()

        transferVolume = await Exchange.connect(customer).custommerSwap(CONTRACT_ADDRESS.WETH, CONTRACT_ADDRESS.USDT, ethers.parseEther('5'))
        logs = await transferVolume.wait()
        let currentFee2 = logs.logs[1].args[5]
        console.log("Current fee: " + currentFee2)

        wethBalance = await contracts.weth.balanceOf(Exchange.target)

        await Exchange.callVoteing([owner1, owner2, owner3])
        await Exchange.connect(owner2).vote(2, true)
        await Exchange.connect(owner3).vote(2, true)

        await Exchange.globalSwap(CONTRACT_ADDRESS.WETH, CONTRACT_ADDRESS.USDT, wethBalance, 2)
        wethBalance = await contracts.weth.balanceOf(Exchange.target)
        USDTBalance = await contracts.usdt.balanceOf(Exchange.target)
        
        // console.log(wethBalance)
        // console.log(USDTBalance)
        
        // await expect(wethBalance).to.be.eq(0)
        // await expect(USDTBalance).to.above(0)
        
        await Exchange.callVoteing([owner1, owner2, owner3])
        await Exchange.connect(owner2).vote(3, true)
        await Exchange.connect(owner3).vote(3, true)

        let toSend = USDTBalance/BigInt(3)
        
        await Exchange.sendToCustomer(
            [
                {
                    token:CONTRACT_ADDRESS.USDT,
                    customer:customer.address, 
                    amount:toSend,
                    returnedFee:currentFee
                },
                {
                    token:CONTRACT_ADDRESS.USDT,
                    customer:customer.address, 
                    amount:toSend,
                    returnedFee:currentFee1
                },
                {
                    token:CONTRACT_ADDRESS.USDT,
                    customer:customer.address, 
                    amount:toSend,
                    returnedFee:currentFee2
                }
            ], 3)
        
        USDTBalance = await contracts.usdt.balanceOf(customer.address)
        console.log("Customer recieved: "+USDTBalance)
        USDTBalance = await contracts.usdt.balanceOf(Exchange.target)
        let usdtCollected = USDTBalance;
        console.log("Contract earned:"+USDTBalance)

        approve = await contracts.weth.approve(Exchange.target,  ethers.parseEther('5'))
        await approve.wait()

        transferVolume = await Exchange.connect(customer).custommerSwap(CONTRACT_ADDRESS.WETH, CONTRACT_ADDRESS.USDT, ethers.parseEther('5'))
        logs = await transferVolume.wait()
        currentFee = logs.logs[1].args[5]
        console.log("Current fee: " + currentFee)

        USDTBalance = await contracts.usdt.balanceOf(customer.address)
        toSend = USDTBalance/BigInt(2)

        approve = await contracts.usdt.approve(Exchange.target,  toSend)
        await approve.wait()

        transferVolume = await Exchange.connect(customer).custommerSwap(CONTRACT_ADDRESS.USDT, CONTRACT_ADDRESS.WETH, toSend)
        logs = await transferVolume.wait()
        currentFee1 = logs.logs[1].args[5]
        console.log("Current fee: " + currentFee1)

        approve = await contracts.usdt.approve(Exchange.target,  toSend)
        await approve.wait()

        transferVolume = await Exchange.connect(customer).custommerSwap(CONTRACT_ADDRESS.USDT, CONTRACT_ADDRESS.WETH, toSend)
        logs = await transferVolume.wait()
        currentFee2 = logs.logs[1].args[5]
        console.log("Current fee: " + currentFee2)

        USDTBalance = await contracts.usdt.balanceOf(Exchange.target) - usdtCollected
        wethBalance = await contracts.weth.balanceOf(Exchange.target)
        toSend = wethBalance/BigInt(2)

        await Exchange.callVoteing([owner1, owner2, owner3])
        await Exchange.connect(owner2).vote(4, true)
        await Exchange.connect(owner3).vote(4, true)
        
        await Exchange.sendToCustomer(
            [
                {
                    token:CONTRACT_ADDRESS.USDT,
                    customer:customer.address, 
                    amount: USDTBalance,
                    returnedFee:currentFee
                },
                {
                    token:CONTRACT_ADDRESS.WETH,
                    customer:customer.address, 
                    amount:toSend,
                    returnedFee:currentFee1
                },
                {
                    token:CONTRACT_ADDRESS.WETH,
                    customer:customer.address, 
                    amount:toSend,
                    returnedFee:currentFee2
                }
            ], 4)

        USDTBalance = await contracts.usdt.balanceOf(customer.address)
        console.log("Customer recieved: "+USDTBalance + " USDT")
        USDTBalance = await contracts.usdt.balanceOf(Exchange.target)
        usdtCollected = USDTBalance
        console.log("Contract earned: "+USDTBalance+" USDT")

        wethBalance = await contracts.weth.balanceOf(customer.address)
        console.log("Customer recieved: "+wethBalance + " WETH")
        wethBalance = await contracts.weth.balanceOf(Exchange.target)
        let wethCollected = wethBalance
        console.log("Contract earned: "+wethCollected+" WETH")

        await Exchange.callVoteing([owner1, owner2, owner3])
        await Exchange.connect(owner2).vote(5, true)
        await Exchange.connect(owner3).vote(5, true)

        await Exchange.setRewards([owner1.address,owner2.address,owner3.address],5)

        let owner1Balance = await Exchange.connect(owner1).checkBalance()
        let owner2Balance = await Exchange.connect(owner2).checkBalance()
        let owner3Balance = await Exchange.connect(owner3).checkBalance()

        console.log(
            "Owner 1 eaarned: " + owner1Balance + "\n" +
            "Owner 2 eaarned: " + owner2Balance + "\n" +
            "Owner 3 eaarned: " + owner3Balance + "\n"
        )

        await Exchange.getReward(CONTRACT_ADDRESS.WETH)
        console.log("Owner reciewed reward: "+await contracts.weth.balanceOf(owner1.address))
        owner1Balance = await Exchange.connect(owner1).checkBalance()
        console.log("left on contract: "+owner1Balance)
    })
});