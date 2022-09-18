const path = require('path')
const fs = require('fs')
const {
  loadFixture
} = require('@nomicfoundation/hardhat-network-helpers')
const { expect } = require('chai')

async function setup() {
  const [owner, player] = await ethers.getSigners()
  const forgeAbi = fs.readFileSync(
    path.resolve(__dirname, '..', '..', 'contracts', 'forge', 'Forge.abi.json'),
    'utf8'
  )
  const forgeBytecode = fs.readFileSync(
    path.resolve(__dirname, '..', '..', 'contracts', 'forge', 'Forge.bytecode.json'),
    'utf8'
  )
  const Forge = await ethers.getContractFactory(JSON.parse(forgeAbi), JSON.parse(forgeBytecode).object)
  const forgeContract = await Forge.deploy()

  // Mint one token id '1' to player
  const mintTx = await forgeContract.connect(owner).mint(player.address, 1, 1, [])
  await mintTx.wait(1)

  return { forgeContract, player }
}

describe('[Challenge] Forge', async function() {
  let forgeContract, player

  before(async function() {
    ({ forgeContract, player } = await loadFixture(setup))
  })

  it('Exploit', async function() {
    
    // Code your exploit here

  })

  after(async function() {
    // Success conditions
    const playerBalanceOf42 = await forgeContract.balanceOf(player.address, 42)
    expect(playerBalanceOf42).to.be.equal('1')
  })
})
