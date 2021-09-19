import Intro from '@/components/Intro'
// import PetSelector from '@/components/PetSelector'
import { ethers } from 'ethers'
import { FC, useEffect, useState } from 'react'
import abi from '../abi/Wagmipet.json'

// import { Wagmipet__factory as Wagmipet, Wagmipet as Wagmiabi } from '@/contracts'

const contractAddress = '0x20f229B5c27e8e164ffe54a6f9b03c56f5F4828B'

const contractABI = abi.abi

const Home: FC = () => {
  // const [web3, setWeb3] = useState<ethers.providers.Web3Provider>(null)
  // const [biconomy, setBiconomy] = useState<Biconomy>(null)
  const [userAddress, setUserAddress] = useState<string>('')
  const [contract, setContract] = useState(null)
  const [ponies, setPonies] = useState([])
  // const contract = useMemo<Wagmiabi>(() => Wagmipet.connect(process.env.NEXT_PUBLIC_CONTRACT_ADDRESS, new ethers.providers.JsonRpcProvider(`https://polygon-mainnet.infura.io/v3/${process.env.NEXT_PUBLIC_INFURA_ID}`)), [])

  // const { data: petList, mutate: mutatePetList } = useSWR<Record<number, string>>(
  // 	() => userAddress && `pets-${userAddress}`,
  // 	() => fetchPets(contract, userAddress),
  // 	{ revalidateOnFocus: false }
  // )

  // useEffect(() => {
  // 	if (!web3) {
  // 		setUserAddress('')
  // 		return
  // 	}

  // 	web3.getSigner().getAddress().then(setUserAddress)
  // }, [web3])

  const connectWallet = () => {
    const { ethereum } = window
    if (!ethereum) {
      alert('Get metamask!')
    }
    ethereum
      .request({ method: 'eth_requestAccounts' })
      .then(accounts => {
        const account = accounts[0]
        console.log('Found an authorized account: ', account)

        const provider = new ethers.providers.Web3Provider(window.ethereum)
        const signer = provider.getSigner()
        const cryptoPonyContract = new ethers.Contract(contractAddress, contractABI, signer)

        setUserAddress(account)
        setContract(cryptoPonyContract)
      })
      .catch(err => console.log(err))
  }

  const checkIfWalletIsConnected = () => {
    // First make sure we have access to window.ethereum
    const { ethereum } = window

    if (!ethereum) {
      console.log('Make sure you have metamask!')
      return
    } else {
      console.log('We have the ethereum object', ethereum)
    }

    ethereum.request({ method: 'eth_accounts' }).then(accounts => {
      if (accounts.length !== 0) {
        const account = accounts[0]
        console.log('Found an authorized account: ', account)

        const provider = new ethers.providers.Web3Provider(window.ethereum)
        const signer = provider.getSigner()
        const cryptoPonyContract = new ethers.Contract(contractAddress, contractABI, signer)

        setUserAddress(account)
        setContract(cryptoPonyContract)
      } else {
        console.log('No authorized account found')
      }
    })
  }

  const getPonies = async () => {
    let ponies = await contract.getAllWaves()

    let tmpPonies = []
    ponies.forEach(pony => {
      tmpPonies.push({
        address: pony.waver,
        timestamp: new Date(pony.timestamp * 1000),
        message: pony.message,
      })
    })

    console.log(tmpPonies)
    setPonies(tmpPonies)
  }

  const PonyViewer: FC<{}> = () => {
    return (
      <div className="flex flex-col items-center justify-center space-y-8">
        <h1 className="text-5xl md:text-7xl text-center dark:text-white">Crypto Ponies</h1>
        <br />
        <h3 className="text-base md:text-5xl text-center dark:text-white">Your Ponies</h3>
        <br />
        {/* <p className="max-w-xs md:max-w-prose text-2xl md:text-3xl text-center dark:text-white">
          Choose one of your $PETs below to visit them, or{' '}
          <button onClick={() => setPetList([], false)} className="underline hover:text-gray-500 dark:hover:text-gray-400">
          adopt a new one
        </button>
          .
        </p> */}
        <div className="flex flex-wrap justify-center gap-8 max-w-5xl mx-auto">
          {['hi', 'yoyo', 'gm', 'gn'].map(pony => (
            //   <Link href={`/pet/${tokenID}`} key={tokenID}>
            <a className="text-3xl p-4 border-4 border-current text-black dark:text-white hover:text-gray-500 dark:hover:text-gray-400 h-60 w-60 flex items-center justify-center text-center">{pony}</a>
            //   </Link>
          ))}
          <a className="text-3xl p-4 border-4 border-current text-black dark:text-white hover:text-gray-500 dark:hover:text-gray-400 h-60 w-60 flex items-center justify-center text-center">Birth Starter Pony</a>
        </div>
      </div>
    )
  }

  useEffect(() => {
    checkIfWalletIsConnected()
  }, [])

  useEffect(() => {
    if (contract) {
      getPonies()
    }
  }, [contract])

  if (!contract || !userAddress) {
    return <Intro connectWallet={connectWallet} />
  }

  return <PonyViewer />

  // if (petList == null) return <LoadingIndicator />

  // if (!biconomy) return <LoadingIndicator />

  // return <MintPet userAddress={userAddress} biconomy={biconomy} setPetList={mutatePetList} />
}

export default Home
