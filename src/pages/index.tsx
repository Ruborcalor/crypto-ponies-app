import Intro from '@/components/Intro'
import LoadingIndicator from '@/components/LoadingIndicator'
import MintPet from '@/components/MintPet'
import PetSelector from '@/components/PetSelector'
import { fetchPets } from '@/lib/fetcher'
import { Biconomy } from '@biconomy/mexa'
import { ethers } from 'ethers'
import { FC, useEffect, useState } from 'react'
import useSWR from 'swr'
// import { Wagmipet__factory as Wagmipet, Wagmipet as Wagmiabi } from '@/contracts'

const Home: FC = () => {
	const [web3, setWeb3] = useState<ethers.providers.Web3Provider>(null)
	const [biconomy, setBiconomy] = useState<Biconomy>(null)
	const [userAddress, setUserAddress] = useState<string>('')
	// const contract = useMemo<Wagmiabi>(() => Wagmipet.connect(process.env.NEXT_PUBLIC_CONTRACT_ADDRESS, new ethers.providers.JsonRpcProvider(`https://polygon-mainnet.infura.io/v3/${process.env.NEXT_PUBLIC_INFURA_ID}`)), [])
	const contract = null

	const { data: petList, mutate: mutatePetList } = useSWR<Record<number, string>>(
		() => userAddress && `pets-${userAddress}`,
		() => fetchPets(contract, userAddress),
		{ revalidateOnFocus: false }
	)

	useEffect(() => {
		if (!web3) {
			setUserAddress('')
			return
		}

		web3.getSigner().getAddress().then(setUserAddress)
	}, [web3])

	if (!web3 || !userAddress) {
		return <Intro setWeb3={setWeb3} setBiconomy={setBiconomy} />
	}

	if (petList == null) return <LoadingIndicator />

	if (Object.keys(petList).length > 0) return <PetSelector petList={petList} setPetList={mutatePetList} />

	if (!biconomy) return <LoadingIndicator />

	return <MintPet userAddress={userAddress} biconomy={biconomy} setPetList={mutatePetList} />
}

export default Home
