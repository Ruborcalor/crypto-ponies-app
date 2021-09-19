import { Biconomy } from '@biconomy/mexa'
import { ethers } from 'ethers'
import { Dispatch, FC, SetStateAction } from 'react'
import ConnectWalletButton from './ConnectWalletButton'
// import TwitterWalletButton from './TwitterWalletButton'

const Intro: FC<{ setWeb3: Dispatch<SetStateAction<ethers.providers.Web3Provider>>; setBiconomy: Dispatch<SetStateAction<Biconomy>> }> = ({ setWeb3, setBiconomy }) => (
	<div className="flex flex-col items-center justify-center space-y-8">
		<h1 className="text-5xl md:text-7xl text-center dark:text-white">Crypto Ponies, on the blockchain</h1>
		<p className="max-w-xs md:max-w-prose text-2xl md:text-3xl text-center dark:text-white">
			Adopt and breed your very own crypo ponies on the blockchain!
			<br />
			<br />
			You can collect them, breed them, and transfer them, getting $LOVE in return.
			<br />
			<br />
			Some Crypto Ponies are rarer than others. Who will collect this most rare Crypto Ponies?!
		</p>
		<div className="space-y-2 flex flex-col items-center justify-center">
			<ConnectWalletButton className="text-3xl p-4 border-4 border-current text-black dark:text-white hover:text-gray-500 dark:hover:text-gray-400" web3={null} setWeb3={setWeb3} setBiconomy={setBiconomy}>
				Connect Wallet
			</ConnectWalletButton>
			{/* <p className="dark:text-white text-xl">
				or{' '}
				<TwitterWalletButton web3={null} setWeb3={setWeb3} setBiconomy={setBiconomy} className="underline">
					log in with Twitter
				</TwitterWalletButton>
				.
			</p> */}
		</div>
	</div>
)

export default Intro
