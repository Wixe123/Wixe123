import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "'SF Pro Text'",
          "'Segoe UI'",
          "Inter",
          "Roboto",
          "'Helvetica Neue'",
          "Arial",
          "sans-serif",
        ],
      },
      colors: {
        base: {
          950: "#09090a",
          900: "#0e0e10",
          800: "#141416",
          700: "#1d1d20",
          600: "#2a2a2e",
        },
        brand: {
          300: "#f2e2b8",
          400: "#e2c789",
          500: "#cca660",
          600: "#a9834a",
        },
        accent: {
          400: "#a8b0bd",
          500: "#848d9c",
        },
        ink: "#100e0a",
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(204,166,96,0.2), 0 10px 30px -8px rgba(204,166,96,0.18)",
      },
      borderRadius: {
        xl2: "0.875rem",
      },
      letterSpacing: {
        wider2: "0.14em",
      },
    },
  },
  plugins: [],
};

export default config;
