const ethers = require('ethers');

const provider = new ethers.JsonRpcProvider('https://mainnet.infura.io/v3/b5c9a42e556a46cda583e1d61fbaaed0');
const test = new ethers.Block
provider.getBlockNumber()
.then(blockNumber => {
  console.log(blockNumber);
})
.catch(error => {
  console.error(error);
});