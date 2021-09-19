import Intro from '@/components/Intro'
import Pony from '@/components/Pony'
// import PetSelector from '@/components/PetSelector'
import { ethers } from 'ethers'
import { FC, useEffect, useState } from 'react'
import abi from '../abi/Wagmipet.json'

// import { Wagmipet__factory as Wagmipet, Wagmipet as Wagmiabi } from '@/contracts'

const contractAddress = '0x953D7a9a37256c9c398816b9D967B20D443f817b'

const contractABI = abi.abi

const Home: FC = () => {
  // const [web3, setWeb3] = useState<ethers.providers.Web3Provider>(null)
  // const [biconomy, setBiconomy] = useState<Biconomy>(null)
  const [userAddress, setUserAddress] = useState<string>('')
  const [contract, setContract] = useState(null)
  const [ponies, setPonies] = useState([])
  const [name, setName] = useState('')
  const [showBirthModal, setShowBirthModal] = useState(false)
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
    let ponies = await contract.tokensOfOwner(userAddress)

    console.log(ponies)

    let tmpPonies = []
    for (let i = 0; i < ponies.length; i++) {
      const pony = ponies[i]
      let thisPony = await contract.getPony(pony.toNumber())
      console.log(`rgb(${thisPony.genes.body.red.toNumber()}, ${thisPony.genes.body.green.toNumber()}, ${thisPony.genes.body.blue.toNumber()}`)
      // genes.body.blue/red/green
      tmpPonies.push(`rgb(${thisPony.genes.body.red.toNumber()}, ${thisPony.genes.body.green.toNumber()}, ${thisPony.genes.body.blue.toNumber()}`)
    }

    console.log(tmpPonies)
    setPonies(tmpPonies)
  }

  const birthPony = async event => {
    event.preventDefault()
    // Who is paying the gas fees for the transaction?
    const waveTxn = await contract.createPromoPony(255, 0, 0, userAddress)

    console.log('Mining...', waveTxn.hash)
    await waveTxn.wait()
    console.log('Mined -- ', waveTxn.hash)
  }

  const PonyViewer: FC<{}> = () => {
    return (
      <>
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
            {ponies.map(pony => (
              //   <Link href={`/pet/${tokenID}`} key={tokenID}>
              <div>
                <div className="text-3xl p-4 border-4 border-current text-black dark:text-white hover:text-gray-500 dark:hover:text-gray-400 h-60 w-60 flex items-center justify-center text-center">
                  <div style={{ transform: 'scale(0.5)' }}>
                    <Pony body={pony} />
                  </div>
                </div>
                <p className="dark:text-white text-center">Test</p>
              </div>
              //   </Link>
            ))}
            <button className="text-3xl p-4 border-4 border-current text-black dark:text-white hover:text-gray-500 dark:hover:text-gray-400 h-60 w-60 flex items-center justify-center text-center" onClick={() => setShowBirthModal(true)}>
              Birth Starter Pony
            </button>
          </div>
        </div>
        {showBirthModal && (
          <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full m-0" id="my-modal" onClick={() => setShowBirthModal(false)}>
            <div className="relative top-80 mx-auto p-5 border-4 w-96 shadow-lg bg-black" onClick={event => event.stopPropagation()}>
              <div className="mt-3 text-center">
                {/* <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100">
                <svg className="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                </svg>
              </div> */}
                <h3 className="text-5xl leading-6 text-white">Birth Pet</h3>
                <br />

                <form onSubmit={birthPony} className="flex flex-col w-full max-w-sm">
                  <input
                    className="text-3xl py-1 px-4 text-center border-4 border-current text-black dark:text-white dark:bg-black focus:outline-none focus-visible:ring"
                    type="text"
                    placeholder="Your awesome new pet"
                    onChange={event => {
                      event.preventDefault()
                      setName((event.target as HTMLInputElement).value)
                    }}
                    value={name}
                    required
                  />
                  <button type="submit" className="text-3xl p-1 border-4 border-t-0 border-current text-black dark:text-white hover:text-gray-500 dark:hover:text-gray-400">
                    Birth
                  </button>
                </form>
                {/* <div className="mt-2 px-7 py-3">
                <p className="text-sm text-gray-500">Account has been successfully registered!</p>
              </div>
              <div className="items-center px-4 py-3">
                <button id="ok-btn" className="px-4 py-2 bg-black text-white text-base font-medium rounded-md w-full shadow-sm hover:bg-green-600 focus:outline-none focus:ring-2 focus:ring-green-300">
                  OK
                </button>
              </div> */}
              </div>
            </div>
          </div>
        )}
      </>
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
