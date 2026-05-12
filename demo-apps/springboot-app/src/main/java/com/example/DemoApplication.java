package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

@SpringBootApplication
public class DemoApplication {
    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }
}

@RestController
class ApiController {
    private static final Random random = new Random();

    @GetMapping("/api/data")
    public Map<String, Object> getData() throws InterruptedException {
        long delay = random.nextInt(100) + 10;
        Thread.sleep(delay);

        Map<String, Object> response = new HashMap<>();
        response.put("data", "success");
        response.put("processing_time_ms", delay);
        return response;
    }

    @GetMapping("/api/slow")
    public Map<String, Object> getSlow() throws InterruptedException {
        long delay = random.nextInt(1500) + 500;
        Thread.sleep(delay);

        Map<String, Object> response = new HashMap<>();
        response.put("data", "slow_response");
        response.put("delay_seconds", delay / 1000.0);
        return response;
    }
}
