package generatedtest;

import io.netty.resolver.SimpleNameResolver;
import io.netty.util.concurrent.Future;

// Test case generated by GenerateFlowTestCase.ql
public class Test {

	Object source() {
		return null;
	}

	void sink(Object o) {}

	public void test() throws Exception {

		{
			// "io.netty.resolver;SimpleNameResolver;false;resolve;(String);;Argument[0];ReturnValue;taint;ai-generated"
			Future out = null;
			String in = (String) source();
			SimpleNameResolver instance = null;
			out = instance.resolve(in);
			sink(out); // $ hasTaintFlow
		}

	}

}