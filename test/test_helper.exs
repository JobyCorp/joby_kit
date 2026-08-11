# Tests tagged :external reach the network (currently: verifying every
# daisyUI docs link still resolves). Excluded from the default run so the
# suite stays offline and fast; run them with `mix test --include external`.
ExUnit.configure(exclude: [:external])
ExUnit.start()
