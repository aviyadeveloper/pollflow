.PHONY: test test-verbose test-unit test-integration install-dev

# Run unit tests (excludes test_*_real.py files that need external APIs)
test:
	@echo "Running poll-generator tests..."
	uv run pytest tests/ -v --ignore=tests/test_news_real.py --ignore=tests/test_llm_real.py --ignore=tests/test_e2e.py

# Run all tests including integration tests
test-all:
	@echo "Running all tests (including integration tests)..."
	uv run pytest tests/ -v

# Run tests with verbose output
test-verbose:
	@echo "Running tests (verbose)..."
	uv run pytest tests/ -vv --ignore=tests/test_news_real.py --ignore=tests/test_llm_real.py --ignore=tests/test_e2e.py

# Run only unit tests (fast, no external dependencies)
test-unit:
	@echo "Running unit tests only..."
	uv run pytest tests/ -v -k "not real and not e2e" --ignore=tests/test_news_real.py --ignore=tests/test_llm_real.py --ignore=tests/test_e2e.py

# Install development dependencies
install-dev:
	@echo "Installing development dependencies..."
	uv sync --group dev

# Build Lambda deployment package
build:
	@echo "Building Lambda deployment package..."
	./build.sh
