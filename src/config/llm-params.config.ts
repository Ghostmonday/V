/**
 * LLM Parameters Configuration
 * Centralized configuration for all LLM-controlled parameters
 * 
 * Control Types:
 * - UI: User can modify via interface
 * - AGENT: LLM agent can modify autonomously  
 * - MANUAL: Requires manual code/env override
 * - HYBRID: Multiple control methods available
 */

export enum ControlType {
  UI = 'UI',
  AGENT = 'AGENT',
  MANUAL = 'MANUAL',
  HYBRID = 'HYBRID'
}

export enum ParameterCategory {
  MODEL = 'MODEL',
  TEMPERATURE = 'TEMPERATURE',
  TOKEN = 'TOKEN',
  RATE_LIMIT = 'RATE_LIMIT',
  MODERATION = 'MODERATION',
  PERFORMANCE = 'PERFORMANCE',
  AUTOMATION = 'AUTOMATION',
  SEARCH = 'SEARCH',
  MAINTENANCE = 'MAINTENANCE'
}

export interface LLMParameter<T = any> {
  id: string;
  category: ParameterCategory;
  name: string;
  description: string;
  defaultValue: T;
  currentValue?: T;
  minValue?: T;
  maxValue?: T;
  unit?: string;
  controlType: ControlType;
  allowedValues?: T[];
  validator?: (value: T) => boolean;
  metadata?: {
    location?: string;
    adjustableBy?: string[];
    criticalParam?: boolean;
    requiresRestart?: boolean;
  };
}

export interface ModelConfig {
  reasoning: string;
  prediction: string;
  automation: string;
  optimizer: string;
  assistants: string;
  embeddings: string;
}

export interface TemperatureConfig {
  reasoning: number;
  prediction: number;
  automation: number;
  assistants: number;
  optimizer: number;
}

export interface TokenConfig {
  maxTokensReasoning: number;
  maxTokensPrediction: number;
  maxTokensAutomation: number;
  maxTokensOptimizer: number;
  costPer1k: number;
  dailySpendLimit: number;
  warningThreshold: number;
}

export interface RateLimitConfig {
  maxCallsPerHour: number;
  windowMs: number;
  hourlyLimit: number;
  warningThreshold: number;
  errorBackoffMs: number;
  analysisTimeoutMs: number;
  heartbeatTimeoutMs: number;
}

export interface ModerationConfig {
  thresholds: {
    default: number;
    illegal: number;
    threat: number;
    pii: number;
    hate: number;
    adult: number;
    probationMultiplier: number;
    toxicityHigh: number;
    toxicityModerate: number;
  };
  maxRepetition: number;
  maxContentLength: number;
}

export interface PerformanceConfig {
  latencyMax: number;
  latencyMin: number;
  errorRateMax: number;
  errorRateMin: number;
}

export interface AutomationConfig {
  rateLimits: {
    global: number;
    ip: number;
    user: number;
  };
  cacheTTLs: {
    l1: number;
    l2: number;
  };
}

export interface SearchConfig {
  matchThreshold: number;
  matchCount: number;
}

export interface MaintenanceConfig {
  windowStartHour: number;
  windowEndHour: number;
  timezone: string;
}

// Default LLM Parameters Configuration
export const LLM_PARAMS_DEFAULT: {
  models: LLMParameter<ModelConfig>;
  temperature: LLMParameter<TemperatureConfig>;
  tokens: LLMParameter<TokenConfig>;
  rateLimits: LLMParameter<RateLimitConfig>;
  moderation: LLMParameter<ModerationConfig>;
  performance: LLMParameter<PerformanceConfig>;
  automation: LLMParameter<AutomationConfig>;
  search: LLMParameter<SearchConfig>;
  maintenance: LLMParameter<MaintenanceConfig>;
} = {
  models: {
    id: 'llm.models',
    category: ParameterCategory.MODEL,
    name: 'LLM Model Selection',
    description: 'AI models used for different operations',
    defaultValue: {
      reasoning: 'gpt-4',
      prediction: 'gpt-4',
      automation: 'deepseek-chat',
      optimizer: 'gpt-4',
      assistants: 'gpt-4',
      embeddings: 'text-embedding-3-small'
    },
    controlType: ControlType.HYBRID,
    metadata: {
      adjustableBy: ['user', 'agent', 'environment'],
      requiresRestart: false
    }
  },

  temperature: {
    id: 'llm.temperature',
    category: ParameterCategory.TEMPERATURE,
    name: 'Temperature Settings',
    description: 'Controls randomness and creativity in LLM outputs',
    defaultValue: {
      reasoning: 0.0,
      prediction: 0.0,
      automation: 0.3,
      assistants: 0.7,
      optimizer: 0.0
    },
    minValue: { reasoning: 0, prediction: 0, automation: 0, assistants: 0, optimizer: 0 },
    maxValue: { reasoning: 2, prediction: 2, automation: 2, assistants: 2, optimizer: 2 },
    controlType: ControlType.HYBRID,
    validator: (value: TemperatureConfig) => {
      return Object.values(value).every(v => v >= 0 && v <= 2);
    },
    metadata: {
      adjustableBy: ['user', 'agent']
    }
  },

  tokens: {
    id: 'llm.tokens',
    category: ParameterCategory.TOKEN,
    name: 'Token Limits & Costs',
    description: 'Response length and cost management',
    defaultValue: {
      maxTokensReasoning: 800,
      maxTokensPrediction: 800,
      maxTokensAutomation: 1000,
      maxTokensOptimizer: 800,
      costPer1k: 0.0001,
      dailySpendLimit: 25,
      warningThreshold: 22.5
    },
    unit: 'tokens/dollars',
    controlType: ControlType.AGENT,
    validator: (value: TokenConfig) => {
      return value.dailySpendLimit > 0 && 
             value.warningThreshold < value.dailySpendLimit &&
             Object.values(value).every(v => typeof v === 'number' && v >= 0);
    },
    metadata: {
      adjustableBy: ['agent'],
      criticalParam: true
    }
  },

  rateLimits: {
    id: 'llm.rateLimits',
    category: ParameterCategory.RATE_LIMIT,
    name: 'Rate Limiting & Throttling',
    description: 'API call frequency and abuse prevention',
    defaultValue: {
      maxCallsPerHour: 100,
      windowMs: 3600000,
      hourlyLimit: 100,
      warningThreshold: 90,
      errorBackoffMs: 300000,
      analysisTimeoutMs: 30000,
      heartbeatTimeoutMs: 30000
    },
    unit: 'calls/ms',
    controlType: ControlType.AGENT,
    validator: (value: RateLimitConfig) => {
      return value.maxCallsPerHour > 0 &&
             value.windowMs > 0 &&
             value.warningThreshold < value.hourlyLimit;
    },
    metadata: {
      adjustableBy: ['agent'],
      criticalParam: true
    }
  },

  moderation: {
    id: 'llm.moderation',
    category: ParameterCategory.MODERATION,
    name: 'Moderation Thresholds',
    description: 'Content filtering and moderation sensitivity',
    defaultValue: {
      thresholds: {
        default: 0.6,
        illegal: 0.7,
        threat: 0.6,
        pii: 0.65,
        hate: 0.55,
        adult: 0.0,
        probationMultiplier: 0.5,
        toxicityHigh: 0.8,
        toxicityModerate: 0.6
      },
      maxRepetition: 20,
      maxContentLength: 50000
    },
    minValue: { 
      thresholds: {
        default: 0, illegal: 0, threat: 0, pii: 0, hate: 0, 
        adult: 0, probationMultiplier: 0, toxicityHigh: 0, toxicityModerate: 0
      },
      maxRepetition: 1,
      maxContentLength: 100
    },
    maxValue: {
      thresholds: {
        default: 1, illegal: 1, threat: 1, pii: 1, hate: 1,
        adult: 1, probationMultiplier: 1, toxicityHigh: 1, toxicityModerate: 1
      },
      maxRepetition: 100,
      maxContentLength: 100000
    },
    controlType: ControlType.AGENT,
    validator: (value: ModerationConfig) => {
      return Object.values(value.thresholds).every(v => v >= 0 && v <= 1) &&
             value.maxRepetition > 0 &&
             value.maxContentLength > 0;
    },
    metadata: {
      adjustableBy: ['agent']
    }
  },

  performance: {
    id: 'llm.performance',
    category: ParameterCategory.PERFORMANCE,
    name: 'Performance Boundaries',
    description: 'Operation performance and resource limits',
    defaultValue: {
      latencyMax: 200,
      latencyMin: 0,
      errorRateMax: 10,
      errorRateMin: 0
    },
    unit: 'ms/%',
    controlType: ControlType.AGENT,
    validator: (value: PerformanceConfig) => {
      return value.latencyMax > value.latencyMin &&
             value.errorRateMax > value.errorRateMin &&
             value.errorRateMax <= 100;
    },
    metadata: {
      adjustableBy: ['agent'],
      criticalParam: true
    }
  },

  automation: {
    id: 'llm.automation',
    category: ParameterCategory.AUTOMATION,
    name: 'AI Automation Parameters',
    description: 'System optimization parameters',
    defaultValue: {
      rateLimits: {
        global: 100,
        ip: 1000,
        user: 100
      },
      cacheTTLs: {
        l1: 60000,
        l2: 300000
      }
    },
    unit: 'requests/ms',
    controlType: ControlType.AGENT,
    metadata: {
      adjustableBy: ['agent']
    }
  },

  search: {
    id: 'llm.search',
    category: ParameterCategory.SEARCH,
    name: 'Semantic Search Parameters',
    description: 'Vector similarity search configuration',
    defaultValue: {
      matchThreshold: 0.78,
      matchCount: 10
    },
    minValue: { matchThreshold: 0.1, matchCount: 1 },
    maxValue: { matchThreshold: 1.0, matchCount: 100 },
    controlType: ControlType.HYBRID,
    validator: (value: SearchConfig) => {
      return value.matchThreshold > 0 && value.matchThreshold <= 1 &&
             value.matchCount > 0;
    },
    metadata: {
      adjustableBy: ['user', 'agent']
    }
  },

  maintenance: {
    id: 'llm.maintenance',
    category: ParameterCategory.MAINTENANCE,
    name: 'Maintenance Window',
    description: 'Hours when AI automation is disabled',
    defaultValue: {
      windowStartHour: 3,
      windowEndHour: 5,
      timezone: 'UTC'
    },
    minValue: { windowStartHour: 0, windowEndHour: 0, timezone: '' },
    maxValue: { windowStartHour: 23, windowEndHour: 23, timezone: '' },
    controlType: ControlType.MANUAL,
    validator: (value: MaintenanceConfig) => {
      return value.windowStartHour >= 0 && value.windowStartHour <= 23 &&
             value.windowEndHour >= 0 && value.windowEndHour <= 23;
    },
    metadata: {
      adjustableBy: ['manual'],
      criticalParam: true,
      requiresRestart: true
    }
  }
};

// Type helpers for parameter access
export type LLMParamsConfig = typeof LLM_PARAMS_DEFAULT;
export type ModelConfigType = ModelConfig;
export type TemperatureConfigType = TemperatureConfig;
export type TokenConfigType = TokenConfig;
export type RateLimitConfigType = RateLimitConfig;
export type ModerationConfigType = ModerationConfig;
export type PerformanceConfigType = PerformanceConfig;
export type AutomationConfigType = AutomationConfig;
export type SearchConfigType = SearchConfig;
export type MaintenanceConfigType = MaintenanceConfig;
