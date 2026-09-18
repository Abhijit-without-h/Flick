import { clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs) {
  return twMerge(clsx(inputs))
}

export const RELEASE = {
  dmg: 'https://github.com/Abhijit-without-h/Flick/releases/latest/download/Flick-1.0.1.dmg',
  zip: 'https://github.com/Abhijit-without-h/Flick/releases/latest/download/Flick-1.0.1.zip',
  page: 'https://github.com/Abhijit-without-h/Flick/releases/latest',
  repo: 'https://github.com/Abhijit-without-h/Flick',
}
