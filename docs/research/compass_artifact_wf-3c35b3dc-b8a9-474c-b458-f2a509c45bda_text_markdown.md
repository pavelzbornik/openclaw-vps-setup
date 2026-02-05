# Optimizing OpenClaw costs with smart model routing on OpenRouter

Using a premium model for every OpenClaw task is financially wasteful—heartbeat checks running on Claude Opus cost **60x more** than they should. Strategic model routing can reduce your monthly OpenClaw spend by **50-80%** without sacrificing quality where it matters. The key is matching model capability to task complexity: ultra-cheap models like **Gemini 2.5 Flash-Lite** ($0.50/M tokens) or **free tier options like MiMo-V2-Flash** handle heartbeats perfectly, while reserving premium models for complex reasoning.

OpenClaw's heartbeat functionality—periodic "are you still there?" checks every 30 minutes—is one of the largest hidden cost drivers. By default, these heartbeats use your primary model, which means potentially **$30/M tokens** for a task that requires almost no intelligence. Combined with sub-agents and simple queries all routing to the same expensive model, users commonly burn **$300-750/month** when **$70-150** would suffice.

## What heartbeats actually need from a model

Heartbeats in OpenClaw serve a specific purpose: the agent wakes periodically, reviews recent context via a `HEARTBEAT.md` checklist file, and decides whether anything needs attention. If nothing requires action, it returns a simple `HEARTBEAT_OK` acknowledgment. The model requirements here are minimal—basic instruction following, simple file reading, and binary decision-making.

For heartbeat tasks, your model needs to:
- Parse a small markdown checklist
- Compare current state against simple conditions
- Return a standardized acknowledgment or alert

This is fundamentally different from complex reasoning, code generation, or multi-step problem solving. A **$0.10-0.50/M token model** performs identically to a **$30/M model** for this workload. The quality ceiling is low, so paying for capabilities you don't use makes no economic sense.

## Top models for heartbeat use cases

The following non-Anthropic models represent the best options for heartbeat tasks, ordered by cost-effectiveness:

| Model | Input Cost | Output Cost | Context | Why It Works |
|-------|-----------|-------------|---------|--------------|
| **MiMo-V2-Flash (free)** | $0.00 | $0.00 | 256K | Xiaomi's MIT-licensed model; #1 on SWE-bench; disable reasoning mode for heartbeats |
| **DeepSeek R1 (free)** | $0.00 | $0.00 | 164K | Full reasoning capabilities at zero cost; rate limited to 50 req/day |
| **GPT-5 Nano** | $0.05 | $0.40 | 32K | OpenAI's smallest flagship variant; reliable paid backup |
| **Gemini 2.5 Flash-Lite** | $0.10 | $0.40 | 1M | Google's cost-efficiency champion; ultra-low latency; thinking disabled by default |
| **DeepSeek V3.2 Exp** | $0.28 | $0.42 | 128K | ~90% cheaper than GPT-4.1; aggressive cache pricing at $0.028 for hits |
| **Kimi K2 0905** | $0.40 | $1.75 | 262K | Moonshot's agentic specialist; excellent tool use at budget pricing |

**Gemini 2.5 Flash-Lite** at **$0.50 combined per million tokens** represents the practical sweet spot—it's cheap enough to make heartbeat costs negligible, fast enough for low-latency responses (~250 tokens/second), and reliable enough for 24/7 production use. For users wanting zero marginal cost, **MiMo-V2-Flash** or **DeepSeek R1's free tier** work excellently but carry rate limit risks.

## Other OpenClaw use cases and recommended models

OpenClaw performs diverse tasks beyond heartbeats. Here's how to route each category cost-effectively:

**Sub-agent parallel work** represents the second-largest cost driver. When your main agent spawns workers for parallel tasks, each sub-agent previously consumed premium tokens. **DeepSeek R1** at **$2.74/M combined** offers reasoning quality competitive with Opus at 10x lower cost—ideal for sub-agents that need to think but don't require frontier capabilities.

**Simple queries** like calendar lookups, weather checks, or file searches need fast, cheap responses. **Gemini 3 Flash** at **$3.50/M combined** provides excellent speed (~250 tok/sec) with strong instruction following. For even cheaper options, **DeepSeek V3.2** handles simple tool use at under $1/M tokens.

**Complex reasoning tasks**—architecture decisions, multi-file refactoring, novel problem-solving—justify premium models. **GPT-5** at **$11.25/M** offers frontier reasoning at better value than Opus, while **Gemini 3 Pro** provides **1 million token context** at $14/M for document-heavy workflows.

**Vision and multimodal tasks** route well to **Gemini 3 Flash** (built-in multimodal) or **Kimi K2.5** (native visual coding capabilities). Both handle image understanding at sub-$5/M pricing.

## The Auto Router alternative

For users who prefer automatic optimization, OpenRouter's **Auto Router** (`openrouter/openrouter/auto`) analyzes prompt complexity and routes to cost-effective models dynamically. Powered by NotDiamond's meta-model system, it routes simple heartbeats to cheap models automatically while escalating complex prompts to capable ones.

The Auto Router pool includes GPT-5 variants, Gemini 3 Pro, DeepSeek V3.2, and other top performers. There's **no additional routing fee**—you pay only the selected model's standard rate. Configure it with guardrails to restrict the model pool:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openrouter/openrouter/auto"
      }
    }
  }
}
```

The tradeoff: less control over exactly which model handles each task, but zero configuration overhead. For users who want predictability, manual tiering (specifying heartbeat and sub-agent models explicitly) provides more transparency.

## Configuration for manual model tiering

The optimal configuration explicitly assigns different models to different task types:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "openai/gpt-5",
        "fallbacks": ["deepseek/deepseek-reasoner", "google/gemini-3-flash"]
      },
      "heartbeat": {
        "every": "30m",
        "model": "google/gemini-2.5-flash-lite",
        "target": "last"
      },
      "subagents": {
        "model": "deepseek/deepseek-reasoner",
        "maxConcurrent": 1
      }
    }
  }
}
```

This configuration achieves three goals: heartbeats cost **$0.50/M** instead of $30, sub-agents run at **$2.74/M** with solid reasoning, and complex user queries still get frontier model quality. The fallback chain uses different providers (OpenAI → DeepSeek → Google) for resilience—if one provider rate-limits, you don't lose all fallbacks.

## Cost impact analysis

The savings from smart routing compound dramatically at scale:

| Usage Level | Before (Single Model) | After (Tiered) | Monthly Savings |
|-------------|----------------------|----------------|-----------------|
| Light (24 heartbeats/day, 20 sub-agents, 10 queries) | ~$200/mo | ~$70/mo | **$130 (65%)** |
| Power (48 heartbeats/day, 100 sub-agents, 50 queries) | ~$943/mo | ~$347/mo | **$596 (63%)** |
| Heavy (multiple agents, parallel work) | ~$2,750/mo | ~$1,000/mo | **$1,750 (64%)** |

The pattern holds across usage levels: **60-65% cost reduction** is achievable without degrading quality on tasks that actually need it. Light users save hundreds annually; heavy users save thousands.

## Why paid beats free for production heartbeats

Free tier models like MiMo-V2-Flash and DeepSeek R1 are tempting for heartbeats, but carry reliability risks. OpenRouter's free tier limits requests to **50/day** and **20/minute**—sufficient for testing but problematic for 24/7 agent operation where a rate limit hit mid-task stops your agent.

The ultra-cheap paid options—Gemini Flash-Lite at $0.10 input, DeepSeek V3.2 at $0.28—cost effectively nothing while guaranteeing availability. A month of continuous heartbeats (1,440 runs) at these prices totals under **$1**. The reliability premium for paid models is measured in pennies but prevents agent downtime.

## Conclusion

The optimal OpenClaw setup for non-Anthropic users combines **Gemini 2.5 Flash-Lite** for heartbeats ($0.50/M), **DeepSeek R1** for sub-agents ($2.74/M), and **GPT-5** or **Gemini 3 Pro** for complex primary tasks. This tiered approach captures 90%+ of potential cost savings while maintaining quality where it matters. For zero-configuration users, OpenRouter's Auto Router provides automatic cost optimization with no setup. Either approach transforms OpenClaw from a "$300/month experiment" into a sustainable, production-ready personal AI infrastructure.