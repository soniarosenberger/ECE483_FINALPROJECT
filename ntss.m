%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% NOTES:
% Clean up regular TSS operation


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Block Based Video Encoder
% Revised 3 Step Search Implementation

% Order of Operations: Per IEEE paper
% 1. Minimum at center - first step stop // completed
% 2. Minimum at edge of center check - halfway stop
% 3. Minimum at corner points - regular TSS operation (following S = 4,2,1)


function ntss
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generic image
close all

reference_frame = double(imread("train01.tif"));
current_frame = double(imread("train02.tif"));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define block size
N = 16;

% Getting height and width of current image
% reference_frame = older image, current frame = now, predicted_frame =
% predicted current image from reference frame blocks.

[height, width] = size(current_frame);
predicted_frame = zeros(height,width);

% Allocate arrays to hold quiver data
quiver_arr = [];


% Calculate total number of SAD computations
sad_counter = 0;


% Iterate through blocks
% Each block will undergo its own 3 step search.
% i - horizontal direction // j - vertical direction

for i = 1:N:width-N+1
    for j = 1:N:height-N+1

        % Set SAD value highest, test for lower SAD.
        % diffx and diffy are best found motion vectors 
        sad = inf;
        diffx = 0;
        diffy = 0;

        % Isolate current frame block
        curr_fb = current_frame(j:j+N-1,i:i+N-1);
        
        % Matrix to record what points have been checked already
        % This ensures no duplicated computation
        checked = false(15,15);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % CHECKING FOR S=1 NEIGHBORING PIXELS & S=4 Coarse NTSS Step 1
        % Calculate SAD for entire block @ each candidate location
        % p - horizontal shift, q - vertical shift
        
        search_loc1 = [0, 0;-1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1;
            -4,-4; -4,0; -4,4; 0,-4; 0,4; 4,-4; 4,0; 4,4];

        for k = 1:size(search_loc1,1)
            p = search_loc1(k,1);
            q = search_loc1(k,2);

            ref_i = i + p;
            ref_j = j + q;

            if (ref_i >= 1 && ref_j >= 1 && ref_i+N-1 <= width && ref_j+N-1 <= height)
                ref_fb = reference_frame(ref_j:ref_j+N-1, ref_i:ref_i+N-1);
                temp_sad = sum(sum(abs(curr_fb - ref_fb)));
                sad_counter = sad_counter + 1;
                checked(q+8,p+8) = true;

                if (temp_sad < sad)
                    sad = temp_sad;
                    diffx = p;
                    diffy = q;
                end
            end 
        end



        % First step stop implementation
        if (diffx == 0 && diffy == 0)
            predicted_frame(j:j+N-1,i:i+N-1) = reference_frame(j+diffy:j+diffy+N-1,i+diffx:i+diffx+N-1);

            % END OF FLOWCHART DECISION #1 (17pts checked// NTSS Step 1)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Perform S = 1 search on minimum point if neighbors central point
        elseif (abs(diffx) + abs(diffy) <= 2)
            search_loc2 = [0, 0;-1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];
            
            for k = 1:size(search_loc2,1)
                p = search_loc2(k,1);
                q = search_loc2(k,2);

                ref_i = i + p;
                ref_j = j + q;

                if ~checked(q+8,p+8)
                    if (ref_i >= 1 && ref_j >= 1 && ref_i+N-1 <= width && ref_j+N-1 <= height)
                        ref_fb = reference_frame(ref_j:ref_j+N-1, ref_i:ref_i+N-1);
                        temp_sad = sum(sum(abs(curr_fb - ref_fb)));
                        sad_counter = sad_counter + 1;
                        checked(q+8,p+8) = true;
                        if (temp_sad < sad)
                            sad = temp_sad;
                            diffx = p;
                            diffy = q;
                        end

                    end
                end
            end
            predicted_frame(j:j+N-1,i:i+N-1) = reference_frame(j+diffy:j+diffy+N-1,i+diffx:i+diffx+N-1);
            quiver_arr = [quiver_arr; i j diffx diffy];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Normal TSS operation after preliminary checks
        % This branch can be more concise. 
        else
        % S = 2 then S = 1 search from the preliminary lowest SAD value loc

        search_loc3 = [0, 0;-2,-2; -2,0; -2,2; 0,-2; 0,2; 2,-2; 2,0; 2,2];
        search_loc4 = [0, 0;-1,-1; -1,0; -1,1; 0,-1; 0,1; 1,-1; 1,0; 1,1];


            for k = 1:size(search_loc3,1)
                p = diffx + search_loc3(k,1); 
                q = diffy + search_loc3(k,2);
                
                if (p >= -7 && p <= 7 && q >= -7 && q <= 7)
                    if ~checked(q+8, p+8)
                        ref_i = i + p;
                        ref_j = j + q;
                        if (ref_i >= 1 && ref_j >= 1 && ref_i+N-1 <= width && ref_j+N-1 <= height)
                            ref_fb = reference_frame(ref_j:ref_j+N-1, ref_i:ref_i+N-1);
                            temp_sad = sum(sum(abs(curr_fb - ref_fb)));
                            sad_counter = sad_counter + 1;
                            checked(q+8,p+8) = true;
                            if (temp_sad < sad)
                                sad = temp_sad;
                                diffx = p;
                                diffy = q;
                            end
                        end
                    end
                end
            end

            for k = 1:size(search_loc4,1)
                p = diffx + search_loc4(k,1);
                q = diffy + search_loc4(k,2);
                
                if (p >= -7 && p <= 7 && q >= -7 && q <= 7)
                    if ~checked(q+8, p+8)
                        ref_i = i + p;
                        ref_j = j + q;
                        if (ref_i >= 1 && ref_j >= 1 && ref_i+N-1 <= width && ref_j+N-1 <= height)
                            ref_fb = reference_frame(ref_j:ref_j+N-1, ref_i:ref_i+N-1);
                            temp_sad = sum(sum(abs(curr_fb - ref_fb)));
                            sad_counter = sad_counter + 1;
                            checked(q+8,p+8) = true;
                            if (temp_sad < sad)
                                sad = temp_sad;
                                diffx = p;
                                diffy = q;
                            end
                        end
                    end
                end
            end
            predicted_frame(j:j+N-1,i:i+N-1) = reference_frame(j+diffy:j+diffy+N-1,i+diffx:i+diffx+N-1);
        end
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    
    quiver_arr = [quiver_arr; i j diffx diffy];
    end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
X = quiver_arr(:,1);
Y = quiver_arr(:,2);
U = quiver_arr(:,3);
V = quiver_arr(:,4);

disp(sad_counter)

figure(2)
imshow(uint8(predicted_frame))
hold on;
quiver(X,Y,U,V,0)

% Error image
err = current_frame - predicted_frame;
figure(3)
imshow(err, [])

psnr = 10*log10(255*255/mean(mean((current_frame - predicted_frame).^2)))

end
% End of blockwise iteration
