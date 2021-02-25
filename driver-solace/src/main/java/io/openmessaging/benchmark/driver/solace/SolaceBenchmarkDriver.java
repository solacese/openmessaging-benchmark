package io.openmessaging.benchmark.driver.solace;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

import org.apache.bookkeeper.stats.StatsLogger;

import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import com.solacesystems.jcsmp.EndpointProperties;
import com.solacesystems.jcsmp.JCSMPException;
import com.solacesystems.jcsmp.JCSMPFactory;
import com.solacesystems.jcsmp.JCSMPProperties;
import com.solacesystems.jcsmp.JCSMPSession;
import com.solacesystems.jcsmp.Queue;
import com.solacesystems.jcsmp.Topic;

import io.openmessaging.benchmark.driver.BenchmarkConsumer;
import io.openmessaging.benchmark.driver.BenchmarkDriver;
import io.openmessaging.benchmark.driver.BenchmarkProducer;
import io.openmessaging.benchmark.driver.ConsumerCallback;

/**
 * Implementation of the OpenMessaging benchmark API for the [Solace
 * PubSub+]{@link https://www.solace.com} event broker.
 * 
 * @author ush.shukla@solace.com
 *
 */
public class SolaceBenchmarkDriver implements BenchmarkDriver {

	private final JCSMPProperties properties = new JCSMPProperties();

	private List<BenchmarkProducer> publishers = Collections.synchronizedList(new ArrayList<>()); // list of all
																									// publishers
																									// currently sending
																									// messages
	private List<BenchmarkConsumer> subscribers = Collections.synchronizedList(new ArrayList<>()); // list of all
																									// subscribers
																									// currently
																									// receiving
																									// messages

	private static final ObjectMapper mapper = new ObjectMapper(new YAMLFactory()) // for parsing properties YAML
			.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

	/**
	 * Sets the {@link JCSMPProperties} for use by the various publisher (producer)
	 * & consumer (subscriber) sessions used during benchmarking.
	 * 
	 * <u>YAML Format</u> <code>
	 * - host: $host:$port
	 * - vpn: $vpn
	 * - username: $username
	 * - password: $password
	 * </code>
	 * 
	 * @param configurationFile broker config file in YAML format
	 * @param statsLogger
	 */

	@Override
	public void initialize(File configurationFile, StatsLogger statsLogger) throws IOException {

		SolaceConfig config = readConfig(configurationFile);

		// properties
		properties.setProperty(JCSMPProperties.HOST, config.host); // host:port
		properties.setProperty(JCSMPProperties.USERNAME, config.username); // username
		properties.setProperty(JCSMPProperties.VPN_NAME, config.vpn); // message-vpn
		properties.setProperty(JCSMPProperties.PASSWORD, config.password); // password

		/*
		 * Is the topic is durable? We follow the naming convention established above by
		 * setting the property name to lower-case.
		 */
		properties.setBooleanProperty("durable", config.durable);
	}

	/*
	 * Parses a broker configuration file.
	 * 
	 * @param configurationFile - YAML file with configuration values for the broker
	 */
	private SolaceConfig readConfig(File configurationFile) throws IOException {
		return mapper.readValue(configurationFile, SolaceConfig.class);
	}

	/**
	 * Returns a prefix for benchmarking topics.
	 * 
	 * @return a prefix prepended to topics used for benchmarking.
	 */
	@Override
	public String getTopicNamePrefix() {
		return "solace/openmessaging/benchmark";
	}

	/**
	 * @param topic      the topic to create
	 * @param partitions unused. Solace PubSub+ does not support partitions
	 */
	@Override
	public CompletableFuture<Void> createTopic(String topic, int partitions) {

		CompletableFuture<Void> future = new CompletableFuture<Void>();

		if (partitions != 1) {
			future.completeExceptionally(new IllegalArgumentException("Solace PubSub+ does not support partitions."));
			return future;
		}

		// we need to create a persistent topic.
		// create a queue & assign it a topic-to-queue mapping.
		if (properties.getBooleanProperty("durable")) {

			CompletableFuture.runAsync(() -> {

				// the topic we want mapped to the queue
				Topic maptopic = JCSMPFactory.onlyInstance().createTopic(topic);

				// Setup the topic-to-queue map
				try {
					Queue queue = provisionBackingQueue();
					JCSMPFactory.onlyInstance().createSession(properties).addSubscription(queue, maptopic,
							JCSMPSession.WAIT_FOR_CONFIRM);
				} catch (JCSMPException ex) {
					ex.printStackTrace();
				}
			});
		} else {

			// Since PubSub+ doesn't need to instantiate
			// non-persistent topics, just print a message and return.
			//TODO: This should be a log message not a println
			future = CompletableFuture
					.runAsync(() -> System.out.println("No need to explicitly create non-persistent topics"));
		}

		return future;
	}

	/*
	 * Provision the backing queue for a persistent-topic scenario
	 */
	private Queue provisionBackingQueue() throws JCSMPException {

		// append a timestamp to make the queue unique
		Queue queue = JCSMPFactory.onlyInstance()
				.createQueue("Q/openmessaging/benchmark/" + Instant.now().toEpochMilli());

		EndpointProperties endprops = new EndpointProperties(EndpointProperties.ACCESSTYPE_NONEXCLUSIVE, null,
				EndpointProperties.PERMISSION_CONSUME, null);

		JCSMPFactory.onlyInstance().createSession(properties).provision(queue, endprops,
				JCSMPSession.FLAG_IGNORE_ALREADY_EXISTS);

		return queue;
	}

	/**
	 * Not used.
	 */
	@Override
	public CompletableFuture<Void> notifyTopicCreation(String topic, int partitions) {
		// no-op
		return null;
	}

	/**
	 * Asynchronously creates a publisher instance for sending messages to a given
	 * topic.
	 * 
	 * @param topic the topic to publish to.
	 */
	@Override
	public CompletableFuture<BenchmarkProducer> createProducer(String topic) {

		SolaceBenchmarkProducer benchmarkProducer = new SolaceBenchmarkProducer(properties, topic);

		try {
			publishers.add(benchmarkProducer);
			return CompletableFuture.completedFuture(benchmarkProducer);
		} catch (Exception e) {

			try {
				benchmarkProducer.close();
			} catch (Exception ex) {
				// TODO: exception handling
			}

			CompletableFuture<BenchmarkProducer> future = new CompletableFuture<>();
			future.completeExceptionally(e);

			return future;
		}
	}

	/**
	 * Asynchronously creates a subscriber (consumer) instance for consuming from a
	 * benchmarking topic.
	 * 
	 * @param topic            the topic to subscribe to (consume messages from)
	 * @param subscriptionName not used
	 * @param partition        not used
	 * @param consumerCallback the callback invoked by a subscriber once it receives
	 *                         a message
	 */
	@Override
	public CompletableFuture<BenchmarkConsumer> createConsumer(String topic, String subscriptionName,
			Optional<Integer> partition, ConsumerCallback consumerCallback) {

		SolaceBenchmarkConsumer benchmarkConsumer = new SolaceBenchmarkConsumer(properties, topic, consumerCallback);

		try {
			subscribers.add(benchmarkConsumer);
			return CompletableFuture.completedFuture(benchmarkConsumer);
		} catch (Exception e) {

			try {
				benchmarkConsumer.close();
			} catch (Exception ex) {
				// TODO: exception handling
			}

			CompletableFuture<BenchmarkConsumer> future = new CompletableFuture<>();
			future.completeExceptionally(e);

			return future;
		}
	}

	/**
	 * Closes all open producer (publisher) & consumer (subscriber) sessions.
	 */
	@Override
	public void close() throws Exception {

		for (BenchmarkProducer producer : publishers)
			producer.close();

		for (BenchmarkConsumer consumer : subscribers)
			consumer.close();
	}
}