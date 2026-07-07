import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        base: {
          950: "#08090d",
          900: "#0e1017",
          800: "#151824",
          700: "#1e2233",
          600: "#2a2f45",
        },
        brand: {
          400: "#a78bfa",
          500: "#7c3aed",
          600: "#6d28d9",
        },
        accent: {
          400: "#22d3ee",
          500: "#06b6d4",
        },
      },
      boxShadow: {
        glow: "0 0 0 1px rgba(124,58,237,0.25), 0 8px 30px rgba(124,58,237,0.15)",
      },
      borderRadius: {
        xl2: "1.25rem",
      },
    },
  },
  plugins: [],
};

export default config;
