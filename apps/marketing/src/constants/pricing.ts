import type { PricingPlanContent } from "./types";

export const pricingPlans = [
  {
    name: "Starter",
    price: 24,
    monthlyPrice: 40,
    description: "Perfect for small teams getting started",
    features: [
      "2 Team Members",
      "10GB Storage",
      "Basic Analytics",
      "Email Support",
    ],
    popular: false,
  },
  {
    name: "Premium",
    price: 99,
    monthlyPrice: 120,
    description: "Best for growing teams with advanced needs",
    features: [
      "10 Team Members",
      "50GB Storage",
      "Advanced Analytics",
      "Priority Support",
    ],
    popular: true,
  },
  {
    name: "Enterprise",
    price: 125,
    monthlyPrice: 150,
    description: "For large organizations requiring scale",
    features: [
      "Unlimited Members",
      "2TB Storage",
      "Custom Integrations",
      "Dedicated Support",
    ],
    popular: false,
  },
] as const satisfies readonly PricingPlanContent[];
