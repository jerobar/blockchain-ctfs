const {
  loadFixture
} = require('@nomicfoundation/hardhat-network-helpers')
const { expect } = require('chai')

async function setup() {
  const [_, player] = await ethers.getSigners()

  const Democracy = await ethers.getContractFactory('Democracy')
  const democracyContract = await Democracy.deploy()

  return { democracyContract, player }
}

describe('[Challenge] Democracy', async function() {
  let democracyContract, player

  before(async function() {
    ({ democracyContract, player } = await loadFixture(setup))
  })

  it('Exploit', async function() {
    
    // Code your exploit here
    
  })

  after(async function() {
    // Success conditions
    const democracyContractBalance = await ethers.provider.getBalance(democracyContract.address)
    expect(democracyContractBalance).to.be.equal('0')
  })
})
