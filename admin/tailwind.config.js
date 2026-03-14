/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#f0f7ff',
          100: '#e0efff',
          200: '#bfe3ff',
          300: '#7cc5ff',
          400: '#36a7ff',
          500: '#0b7aff',
          600: '#0061dd',
          700: '#004db3',
          800: '#003a85',
          900: '#00285c',
        },
      },
    },
  },
  plugins: [],
}
